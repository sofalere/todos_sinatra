require "sinatra"
require "sinatra/reloader" if development?
require "sinatra/content_for"
require "tilt/erubis"

configure do
  enable :sessions
  set :session_secret, 'secret'
end

# VIEW helpers, code specific for erb files
helpers do
# Display how many todos are incomplete/ total todos
  def display_todo_counter(list)
    incomplete = list[:todos].count { |todo| !todo[:completed] }
    "#{incomplete} / #{list[:todos].size}"
  end

# Check if all todos are completed
  def all_complete?(list)
    list[:todos].all? { |todo| todo[:completed] } &&
    list[:todos].size > 0
  end
  
# Determine list class
  def list_class(list)
    "complete" if all_complete?(list)
  end
  
# Sort completed items at bottom of list
  def sort_lists(lists, &block)
    complete, incomplete = lists.partition { |list| all_complete?(list) }
    
    incomplete.each { |list| yield(list, lists.index(list)) }
    complete.each { |list| yield(list, lists.index(list)) }
  end

  def sort_todos(todos, &block)
    complete, incomplete = todos.partition { |todo| todo[:completed] }
    
    incomplete.each { |todo| yield(todo, todos.index(todo)) }
    complete.each { |todo| yield(todo, todos.index(todo)) }
  end
end

before do
  session[:lists] ||= []
end

get "/" do
  redirect "/lists"
end

# Display all lists
get "/lists" do
  @lists = session[:lists]
    
  erb :lists, layout: :layout
end

# Render new list form
get "/lists/new" do
  erb :new_list, layout: :layout
end

# Return an error message if name is invalid, nil if name is successful
def error_for_list_name(name)
  if !(1..100).cover?(name.size)
    "The list name must be between 1 and 100 characters."
  elsif session[:lists].any? { |list| list[:name] == name }
    "List name must be unique."
  end
end

# Return an error message if name is invalid, nil if name is successful
def error_for_todo_name(todo_name)
  if !(1..100).cover?(todo_name.size)
    "The todo todo must be between 1 and 100 characters."
  end
end

# Create a new list
post "/lists" do
  list_name = params[:list_name].strip
  
  error = error_for_list_name(list_name)
  if error
    session[:error] = error
    erb :new_list, layout: :layout
  else 
    session[:lists] << { name: list_name, todos: [] }
    session[:success] = "The list has been created."

    redirect "/lists"
  end
end

# Render a single list
get "/lists/:id" do
  @list_id = params[:id].to_i
  @list = session[:lists][@list_id]

  erb :list, layout: :layout
end

# Edit an existing todo list
get "/lists/:id/edit" do
  id = params[:id].to_i
  @list = session[:lists][id]
  
  erb :edit_list, layout: :layout
end

# Update an existing to do list 
post "/lists/:id" do
  id = params[:id].to_i
  @list = session[:lists][id]
  list_name = params[:list_name].strip
  
  error = error_for_list_name(list_name)
  if error
    session[:error] = error
    erb :edit_list, layout: :layout
  else 
    @list[:name] = list_name
    session[:success] = "The list has been updated."

    redirect "/lists/#{id}"
  end
end

# Delete a list
post "/lists/:id/destroy" do
  id = params[:id].to_i
  session[:lists].delete_at(id)
  session[:success] = "The list has been deleted."
  
  redirect '/lists'
end

# Add a new todo to a list
post "/lists/:list_id/todos" do
  @list_id = params[:list_id].to_i
  todo = params["todo"].strip
  @list = session[:lists][@list_id]
  error = error_for_todo_name(todo)
 
  if error
    session[:error] = error
    
    erb :list, layout: :layout
  else
    @list[:todos] << {name: todo, completed: false}
    session[:success] = "The todo has been added."
    
    redirect "/lists/#{@list_id}"
  end
end

# Delete a todo on a list
post "/lists/:list_id/todos/:id/destroy" do
  @list_id = params[:list_id].to_i
  @list = session[:lists][@list_id]
  
  todo_id = params[:id].to_i
  @list[:todos].delete_at(todo_id)
  session[:success] = "The todo has been deleted."

  redirect "/lists/#{@list_id}"
end

# Update status of a todo
post "/lists/:list_id/todos/:id" do
  @list_id = params[:list_id].to_i
  @list = session[:lists][@list_id]
  
  todo_id = params[:id].to_i
  is_completed = params[:completed] == "true"
  @list[:todos][todo_id][:completed] = is_completed
  session[:success] = "The todo has been updated."

  redirect "/lists/#{@list_id}"
end

# Mark all todos as complete for a list
post "/lists/:id/complete_all" do
  @list_id = params[:id].to_i
  @list = session[:lists][@list_id]

  @list[:todos].each { |todo| todo[:completed] = true }
  session[:success] = "All todos have been completed."
  
  redirect "/lists/#{@list_id}"
end