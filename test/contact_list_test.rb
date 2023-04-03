ENV["RACK_ENV"] = "test"

require "minitest/autorun"
require "rack/test"
require "fileutils"

require_relative "../contact_list"

configure do
  enable :sessions
end

class ContactListTest < Minitest::Test
  include Rack::Test::Methods

  def app
    Sinatra::Application
  end

  def session
    last_request.env["rack.session"]
  end

  def admin_session
    { "rack.session" => { user: "admin" }}
  end

  def setup
    FileUtils.mkdir_p(data_path)
    content = [{"name" => "Mimi",
                "phone" => "(999) 999-9999",
                "email" => "mimi@gmail.com",
                "type" => "family"},
               {"name" => "Hudson",
                "phone" => "(123) 456-7890",
                "email" => "mrman@gmail.com",
                "type" => "friend"},
               {"name" => "Ruby",
                "phone" => "(010) 101-0101",
                "email" => "gems@gmail.com",
                "type" => "work"},
               {"name" => "User",
                "phone" => "(555) 555-5555",
                "email" => "user@mail.com",
                "type" => "other"}]

    File.open(File.join(data_path, "contacts.yml"), "w") do |file|
      file.write(content.to_yaml)
    end
  end

  def teardown
    FileUtils.rm_rf(data_path)
  end

  def test_index
    get "/"
    assert_equal 200, last_response.status
    assert_equal "text/html;charset=utf-8", last_response["Content-type"]
    assert_includes last_response.body, "<h1>Contact Tracker"
    assert_includes last_response.body, %q(<button type="signin">Sign In</button>)
  end

  def test_view_new_contact_form
    get "/new", {}, admin_session
    assert_equal 200, last_response.status
    assert_equal "text/html;charset=utf-8", last_response["Content-type"]
    assert_includes last_response.body, %q(<label for="phone")
    assert_includes last_response.body, "Submit</button>"
  end

  def test_view_new_contact_form_signed_out
    get "/new"
    assert_equal 302, last_response.status
    assert_equal "You must be signed in to perform that action.", session[:message]
  end

  def test_add_contact
    post "/new", {name: "link", phone: "1112223333", email: "link@hyrule.com", type: "work"}, admin_session

    assert_equal 302, last_response.status

    assert_equal "Contact 'Link' added", session[:message]

    get last_response["Location"]
    assert_includes last_response.body, "<h1>Contact Tracker"
  end

  def test_add_contact_signed_out
    post "/new", {name: "link", phone: "1112223333", email: "link@hyrule.com", type: "work"}
    assert_equal 302, last_response.status
    assert_equal "You must be signed in to perform that action.", session[:message]
  end

  def test_add_contact_with_empty_name
    post "/new", {name: "", phone: "1112223333", email: "link@hyrule.com", type: "work"}, admin_session

    assert_equal 422, last_response.status

    assert_includes last_response.body, "Name entry cannot be left blank."
  end

  def test_add_contact_with_short_phone_number
    post "/new", {name: "link", phone: "111", email: "link@hyrule.com", type: "work"}, admin_session

    assert_equal 422, last_response.status

    assert_includes last_response.body, "Phone number must contain 10 digits."

    post "/new", {name: "link", phone: "", email: "link@hyrule.com", type: "work"}
    assert_equal 422, last_response.status

    assert_includes last_response.body, "Phone number must contain 10 digits."
  end

  def test_add_contact_with_long_phone_number
    post "/new", {name: "link", phone: "11122233334444", email: "link@hyrule.com", type: "work"}, admin_session

    assert_equal 422, last_response.status

    assert_includes last_response.body, "Phone number must contain 10 digits."
  end

  def test_add_contact_with_empty_email
    post "/new", {name: "link", phone: "1112223333", email: "", type: "work"}, admin_session

    assert_equal 422, last_response.status

    assert_includes last_response.body, "Email entry cannot be left blank."
  end

  def test_add_contact_with_empty_email
    post "/new", {name: "link", phone: "1112223333", email: "link@hyrule.com", type: nil}, admin_session

    assert_equal 422, last_response.status

    assert_includes last_response.body, "You must select a category."
  end

  def test_view_family_contacts
    get "/contacts/family"
    assert_equal 200, last_response.status
    assert_equal "text/html;charset=utf-8", last_response["Content-type"]
    assert_includes last_response.body, "Mimi"
  end

  def test_view_friend_contacts
    get "/contacts/friends"
    assert_equal 200, last_response.status
    assert_equal "text/html;charset=utf-8", last_response["Content-type"]
    assert_includes last_response.body, "Hudson"
  end

  def test_view_work_contacts
    get "/contacts/work"
    assert_equal 200, last_response.status
    assert_equal "text/html;charset=utf-8", last_response["Content-type"]
    assert_includes last_response.body, "Ruby"
  end

  def test_view_other_contacts
    get "/contacts/other"
    assert_equal 200, last_response.status
    assert_equal "text/html;charset=utf-8", last_response["Content-type"]
    assert_includes last_response.body, "User"
  end

  def test_view_contact_card
    get "/contacts/entry/Hudson"
    assert_equal 200, last_response.status
    assert_equal "text/html;charset=utf-8", last_response["Content-type"]
    assert_includes last_response.body, "Name:</strong> Hudson</li>"
    assert_includes last_response.body, "<a href=mailto:mrman@gmail.com>mrman@gmail.com</a>"
  end

  def test_edit_form
    get '/contacts/entry/Hudson/edit', {}, admin_session

    assert_equal 200, last_response.status
    assert_equal "text/html;charset=utf-8", last_response["Content-type"]
    assert_includes last_response.body, %q(<button class="submit" type="save_changes">Save changes</button>)
  end

  def test_edit_form_signed_out
    get '/contacts/entry/Hudson/edit'
    assert_equal 302, last_response.status
    assert_equal "You must be signed in to perform that action.", session[:message]
  end

  def test_edit
    post "/edit", {name: "Hudson", phone: "(123) 456-7890", email: "mrman@gmail.com", type: "family"}, admin_session

    assert_equal "Contact 'Hudson' edited.", session[:message]

    get "/contacts/entry/Hudson"
    assert_includes last_response.body, "Category:</strong> Family</li>"
  end

  def test_edit_signed_out
    post "/edit", {name: "Hudson", phone: "(123) 456-7890", email: "mrman@gmail.com", type: "family"}
    assert_equal 302, last_response.status
    assert_equal "You must be signed in to perform that action.", session[:message]
  end

  def test_delete
    post "/contacts/entry/Mimi/delete", {}, admin_session

    assert_equal "Contact 'Mimi' deleted.", session[:message]

    get last_response["Location"]
    get "/contacts/all"
    refute_includes last_response.body, "Mimi"
  end

  def test_delete_signed_out
    post "/contacts/entry/Mimi/delete"

    assert_equal 302, last_response.status
    assert_equal "You must be signed in to perform that action.", session[:message]
  end

  def test_duplicate_name
    post "/new", {name: "hudson", phone: "1234567890", email: "woof@dingo.net", type: "family"}, admin_session

    assert_equal 422, last_response.status

    assert_includes last_response.body, "Name entry must be unique."
  end

  def test_signin_form
    get "/users/signin"
    assert_equal 200, last_response.status
    assert_includes last_response.body, "<form action="
    assert_includes last_response.body, "<button type="
  end

  def test_signin
    post '/users/signin', username: "admin", password: "secret"
    assert_equal 302, last_response.status
    assert_equal "Welcome!", session[:message]
    assert_equal "admin", session[:user]

    get last_response["Location"]
    assert_includes last_response.body, "Signed in as admin"
  end

  def test_failed_signin
    post '/users/signin', username: "user", password: "whoops"
    assert_equal 422, last_response.status
    assert_nil session[:username]
    assert_includes last_response.body, "Invalid credentials"
  end

  def test_signout
    get "/", {}, {"rack.session" => {user: "admin" }}
    assert_includes last_response.body, "Signed in as admin"

    post '/users/signout'
    assert_equal "You have been signed out.", session[:message]

    get last_response["Location"]
    assert_nil session[:user]
    assert_includes last_response.body, %q(<button type="signin">)
  end
end