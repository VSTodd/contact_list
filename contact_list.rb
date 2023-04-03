# Contact View
  # Displays Info
  # Delete button (only works if logged in)
  # Edit button (only if logged in)

require "sinatra"
require "sinatra/reloader"
require "tilt/erubis"
require "yaml"
require "bcrypt"

configure do
  enable :sessions
  set :session_secret, 'super secret'
end

def alphabetize(array)
  array.sort_by { |hash| hash["name"] }
end

def duplicate?(name)
  contacts = YAML.load_file(File.join(data_path, "contacts.yml"))
  contacts.each do |contact|
    return true if contact["name"].downcase == name.downcase
  end
  false
end

def data_path
  if ENV["RACK_ENV"] == "test"
    File.expand_path("../test/data", __FILE__)
  else
    File.expand_path("../data", __FILE__)
  end
end

def validate_entries_new(name, phone, email, type)
  digits = phone.gsub(/\D/, "")
  if name == ""
    session[:message] = "Name entry cannot be left blank."
  elsif duplicate?(name)
    session[:message] = "Name entry must be unique."
  elsif digits.length != 10
    session[:message] = "Phone number must contain 10 digits."
  elsif email == ""
    session[:message] = "Email entry cannot be left blank."
  elsif type == nil
    session[:message] = "You must select a category."
  else
    false
  end
end

def validate_entries_edit(name, phone, email, type)
  digits = phone.gsub(/\D/, "")
  if name == ""
    session[:message] = "Name entry cannot be left blank."
  elsif digits.length != 10
    session[:message] = "Phone number must contain 10 digits."
  elsif email == ""
    session[:message] = "Email entry cannot be left blank."
  elsif type == nil
    session[:message] = "You must select a category."
  else
    false
  end
end

def validate_logged_in
  unless session[:user]
  session[:message] = "You must be signed in to perform that action."
    redirect "/contacts/entry/#{params[:name]}" if params[:name]
    redirect "/"
  end
end

def format_name(name)
  name.split.map(&:capitalize).join(" ")
end

def format_phone_number(phone)
  digits = phone.gsub(/\D/, "")
  "(#{digits[0..2]}) #{digits[3..5]}-#{digits[6..9]}"
end

def load_user_credentials
  credentials_path = if ENV["RACK_ENV"] == "test"
    File.expand_path("../test/users.yml", __FILE__)
  else
    File.expand_path("../users.yml", __FILE__)
  end
  YAML.load_file(credentials_path)
end

def valid_credentials?(username, password)
  credentials = load_user_credentials

  if credentials.key?(username)
    bcrypt_password = BCrypt::Password.new(credentials[username])
    bcrypt_password == password
  else
    false
  end
end

helpers do
  def phone_strip(phone_number)
    phone_number.gsub(/\D/, "")
  end
end

get "/" do
  erb :index
end

get "/new" do
  validate_logged_in
  erb :new
end

post "/new" do
  validate_logged_in
  if validate_entries_new(params[:name], params[:phone], params[:email], params[:type])
    status 422
    erb :new
  else
    new_contact = Hash.new
    new_contact["name"] = format_name(params[:name])
    new_contact["phone"] = format_phone_number(params[:phone])
    new_contact["email"] = params[:email]
    new_contact["type"] = params[:type]

    current_contacts = YAML.load_file(File.join(data_path, "contacts.yml"))
    current_contacts << new_contact

    File.open(File.join(data_path, "contacts.yml"), 'w') do |file|
      file.write(current_contacts.to_yaml)
    end

    session[:message] = "Contact '#{format_name(params[:name])}' added"
    redirect "/"
  end
end

get "/contacts/all" do
  @contacts = alphabetize(YAML.load_file(File.join(data_path, "contacts.yml")))
  @title = "Contacts (All)"
  erb :contacts
end

get "/contacts/friends" do
  @contacts = alphabetize(YAML.load_file(File.join(data_path, "contacts.yml")))
  @contacts.select! { |contact| contact["type"] == "friend" }
  @title = "Contacts - Friends"
  erb :contacts
end

get "/contacts/family" do
  @contacts = alphabetize(YAML.load_file(File.join(data_path, "contacts.yml")))
  @contacts.select! { |contact| contact["type"] == "family" }
  @title = "Contacts - Family"
  erb :contacts
end

get "/contacts/work" do
  @contacts = alphabetize(YAML.load_file(File.join(data_path, "contacts.yml")))
  @contacts.select! { |contact| contact["type"] == "work" }
  @title = "Contacts - Work"
  erb :contacts
end

get "/contacts/other" do
  @contacts = alphabetize(YAML.load_file(File.join(data_path, "contacts.yml")))
  @contacts.select! { |contact| contact["type"] == "other" }
  @title = "Contacts - Other"
  erb :contacts
end

get "/contacts/entry/:name" do
  contacts = YAML.load_file(File.join(data_path, "contacts.yml"))
  @entry = {}
  contacts.each { |hash| @entry = hash if hash["name"] == params[:name] }
  erb :contact
end

get '/contacts/entry/:name/edit' do
  validate_logged_in
  @contacts = YAML.load_file(File.join(data_path, "contacts.yml"))
  @entry = nil

  @contacts.each { |contact| @entry = contact if contact["name"] == params[:name] }
  session[:edited] = @entry
  erb :edit
end

post "/edit" do
  validate_logged_in

  if validate_entries_edit(params[:name], params[:phone], params[:email], params[:type])
    status 422
    erb :new
  else
    new_contact = Hash.new
    new_contact["name"] = format_name(params[:name])
    new_contact["phone"] = format_phone_number(params[:phone])
    new_contact["email"] = params[:email]
    new_contact["type"] = params[:type]

    current_contacts = YAML.load_file(File.join(data_path, "contacts.yml"))
    current_contacts.delete(session[:edited])
    current_contacts << new_contact

    File.open(File.join(data_path, "contacts.yml"), 'w') do |file|
      file.write(current_contacts.to_yaml)
    end

    session[:message] = "Contact '#{format_name(params[:name])}' edited."
    session[:edited] = nil
    redirect "/"
  end
end

post '/contacts/entry/:name/delete' do
  validate_logged_in

  contacts = YAML.load_file(File.join(data_path, "contacts.yml"))
  contacts.each do |contact|
    contacts.delete(contact) if contact["name"] == params[:name]
  end

  File.open(File.join(data_path, "contacts.yml"), 'w') do |file|
    file.write(contacts.to_yaml)
  end

  session[:message] = "Contact '#{params[:name]}' deleted."
  redirect "/"
end

get "/users/signin" do
  erb :signin
end

post "/users/signin" do
  username = params[:username]

  if valid_credentials?(username, params[:password])
    session[:user] = params[:username]
    session[:message] = "Welcome!"
    redirect "/"
  else
    session[:message] = "Invalid credentials"
    status 422
    erb :signin
  end
end

post '/users/signout' do
  session.delete(:user)
  session[:message] = "You have been signed out."
  redirect "/"
end