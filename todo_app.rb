require "sinatra"
require "sinatra/reloader" if development?
require "sinatra/content_for"
require "tilt/erubis"
require "rack"

configure do
  enable :sessions
  set :session_secret, 'secret'
  set :erb, :escape_html => true
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
    
    incomplete.each(&block)
    complete.each(&block)
  end

  def sort_todos(todos, &block)
    complete, incomplete = todos.partition { |todo| todo[:completed] }
    
    incomplete.each(&block)
    complete.each(&block)
  end
end

# Validate list exists
def load_list(id)
  loaded_list = session[:lists].find { |list| list[:id] == id }
  return loaded_list if loaded_list

  session[:error] = "The specified list was not found."
  redirect "/lists"
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

# Generate id numbers for ordered elements
def next_element_id(elements)
  max = elements.map { |element| element[:id] }.max || 0
  max + 1
end

before do
  session[:lists] ||= []
end

get "/clear_all" do
  session[:lists] = nil
  
  redirect "/lists"
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

# Create a new list
post "/lists" do
  list_name = params[:list_name].strip
  
  error = error_for_list_name(list_name)
  if error
    session[:error] = error
    erb :new_list, layout: :layout
  else
    id = next_element_id(session[:lists])
    session[:lists] << { id: id, name: list_name, todos: [] }
    session[:success] = "The list has been created."

    redirect "/lists"
  end
end

# Render a single list
get "/lists/:id" do
  id = params[:id].to_i
  @list = load_list(id)
  @list_name = @list[:name]
  @list_id = @list[:id]
  @todos = @list[:todos]
  erb :list, layout: :layout
end

# Edit an existing todo list
get "/lists/:id/edit" do
  id = params[:id].to_i
  @list = load_list(id)
  
  erb :edit_list, layout: :layout
end

# Update an existing to do list 
post "/lists/:id" do
  id = params[:id].to_i
  @list = load_list(id)
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
  session[:lists].reject! { |list| list[:id] == id }
  session[:success] = "The list has been deleted."

  if env["HTTP_X_REQUESTED_WITH"] === "XMLHttpRequest"
    "/lists"
  else
    redirect '/lists'
  end
end

# Add a new todo to a list
post "/lists/:list_id/todos" do
  @list_id = params[:list_id].to_i
  todo = params["todo"].strip
  @list = load_list(@list_id)
  error = error_for_todo_name(todo)
 
  if error
    session[:error] = error
    erb :list, layout: :layout
  else
    id = next_element_id(@list[:todos])
    @list[:todos] << { id: id, name: todo, completed: false}

    session[:success] = "The todo has been added."
    redirect "/lists/#{@list_id}"
  end
end

# Delete a todo from a list
post "/lists/:list_id/todos/:id/destroy" do
  @list_id = params[:list_id].to_i
  @list = load_list(@list_id)
  
  todo_id = params[:id].to_i
  @list[:todos].reject! { |todo| todo[:id] == todo_id }
  if env["HTTP_X_REQUESTED_WITH"] === "XMLHttpRequest"
    status 204
  else
    session[:success] = "The todo has been deleted."
    redirect "/lists/#{@list_id}"
  end
end

# Update status of a todo
post "/lists/:list_id/todos/:id" do
  @list_id = params[:list_id].to_i
  @list = load_list(@list_id)
  
  todo_id = params[:id].to_i
  is_completed = params[:completed] == "true"
  todo = @list[:todos].find { |todo| todo[:id] == todo_id }
  todo[:completed] = is_completed
  
  session[:success] = "The todo has been updated."
  redirect "/lists/#{@list_id}"
end

# Mark all todos as complete for a list
post "/lists/:id/complete_all" do
  @list_id = params[:id].to_i
  @list = load_list(@list_id)

  @list[:todos].each { |todo| todo[:completed] = true }
  session[:success] = "All todos have been completed."
  
  redirect "/lists/#{@list_id}"
end