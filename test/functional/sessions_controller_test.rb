require 'test_helper'
require 'sessions_controller'

# Re-raise errors caught by the controller.
class SessionsController; def rescue_action(e)
                            fail e
                          end; end

class SessionsControllerTest < ActionController::TestCase
  # Be sure to include AuthenticatedTestHelper in test/test_helper.rb instead
  # Then, you can remove it from this and the units test.
  include AuthenticatedTestHelper

  fixtures :users, :people

  def setup
    @controller = SessionsController.new
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new

    Seek::Config.omniauth_providers = {
      ldap: {
        title: 'organization-ldap',
        host: 'localhost',
        port: 389,
        method: :plain,
        base: 'DC=example,DC=com',
        uid: 'samaccountname',
        password: '',
        bind_dn: ''
      }
    }

    # add an omniauth user
    auth_hash = {
      provider: 'ldap',
      uid: 'new_ldap_user',
      info: { 'nickname' => 'new_ldap_user', 'first_name' => 'new', 'last_name' => 'ldap_user', 'email' => 'new_ldap_user@example.com' }
    }
    OmniAuth.config.add_mock(:ldap, auth_hash)
  end

  test 'sessions#index redirects to session#new' do
    get :index
    assert_redirected_to root_path
  end

  test 'session#show redirects to root page' do
    get :show
    assert_redirected_to root_path
  end

  def test_index_not_logged_in
    get :new
    assert_response :success

    User.destroy_all # remove all users
    assert_equal 0, User.count
    get :new
    assert_response :redirect
    assert_redirected_to signup_url
  end

  def test_title
    get :new
    assert_select 'title', text: /The Sysmo SEEK.*/, count: 1
  end

  def test_should_login_and_redirect
    post :create, login: 'quentin', password: 'test'
    assert session[:user_id]
    assert_response :redirect
  end

  # FIXME: check whether doing a redirect is a problem - this is a test generated by the restful_auth.. plugin, so is clearly there for a reason
  #  def test_should_fail_login_and_not_redirect
  #    post :create, :login => 'quentin', :password => 'bad password'
  #    assert_nil session[:user_id]
  #    assert_response :success
  #  end

  def test_should_logout
    login_as :quentin
    @request.env['HTTP_REFERER'] = '/data_files'
    get :destroy
    assert_nil session[:user_id]
    assert_response :redirect
  end

  def test_should_remember_me
    post :create, login: 'quentin', password: 'test', remember_me: 'on'
    assert_not_nil @response.cookies['auth_token']
  end

  def test_should_not_remember_me
    post :create, login: 'quentin', password: 'test', remember_me: 'off'
    assert_nil @response.cookies['auth_token']
  end

  def test_should_delete_token_on_logout
    login_as :quentin
    @request.env['HTTP_REFERER'] = '/data_files'
    get :destroy
    assert_equal @response.cookies['auth_token'], nil
  end

  def test_should_login_with_cookie
    users(:quentin).remember_me
    @request.cookies['auth_token'] = cookie_for(:quentin)
    get :new
    assert @controller.send(:logged_in?)
  end

  def test_should_fail_expired_cookie_login
    users(:quentin).remember_me
    users(:quentin).update_attribute :remember_token_expires_at, 5.minutes.ago
    @request.cookies['auth_token'] = cookie_for(:quentin)
    get :new
    assert !@controller.send(:logged_in?)
  end

  def test_should_fail_cookie_login
    users(:quentin).remember_me
    @request.cookies['auth_token'] = 'invalid_auth_token'
    get :new
    assert !@controller.send(:logged_in?)
  end

  def test_non_activated_user_should_redirect_to_new_with_message
    user = Factory(:brand_new_user, person: Factory(:person))
    post :create, login: user.login, password: user.password
    assert !session[:user_id]
    assert_redirected_to login_path
    assert_not_nil flash[:error]
    assert flash[:error].include?('You still need to activate your account.')
  end

  def test_partly_registed_user_should_redirect_to_select_person
    user = Factory(:brand_new_user)
    post :create, login: user.login, password: user.password
    assert session[:user_id]
    assert_equal user.id, session[:user_id]
    assert_not_nil flash.now[:notice]
    assert_redirected_to register_people_path
  end

  test 'should redirect to root after logging out from the search result page' do
    login_as :quentin
    @request.env['HTTP_REFERER'] = 'http://test.host/search/'
    get :destroy
    assert_redirected_to :root
  end

  test 'should redirect to back after logging out from the page excepting search result page' do
    login_as :quentin
    @request.env['HTTP_REFERER'] = 'http://test.host/data_files/'
    get :destroy
    assert_redirected_to :back
  end

  test 'should redirect to root after logging in from the search result page' do
    @request.env['HTTP_REFERER'] = 'http://test.host/search'
    post :create, login: 'quentin', password: 'test'
    assert_redirected_to :root
  end

  test 'should redirect to back after logging in from the page excepting search result page' do
    @request.env['HTTP_REFERER'] = 'http://test.host/data_files/'
    post :create, login: 'quentin', password: 'test'
    assert_redirected_to :back
  end

  test 'should have only seek login' do
    assert !Seek::Config.omniauth_enabled
    get :new
    assert_response :success
    assert_select 'title', text: /The.*SEEK Login/, count: 1
    assert_select '#login-panel form', 1
  end

  test 'should have ldap login' do
    # change the setting
    Seek::Config.omniauth_enabled   = true
    Seek::Config.omniauth_providers = {
      ldap: {
        title: 'organization-ldap',
        host: 'localhost',
        port: 389,
        method: :plain,
        base: 'DC=example,DC=com',
        uid: 'samaccountname',
        password: '',
        bind_dn: ''
      }
    }

    get :new
    assert_response :success
    assert_select '#login-panel form', 2
    assert_select '#ldap_login input[name="username"]', 1
    assert_select '#ldap_login input[name="password"]', 1
  end

  test 'should not create omni authenticated user' do
    # change the setting
    Seek::Config.omniauth_enabled     = true
    Seek::Config.omniauth_user_create = false
    @request.env['omniauth.auth'] = OmniAuth.config.mock_auth[:ldap]

    post :create
    assert_redirected_to login_path
    assert_match(/the authenticated user: .+ cannot be found/, flash[:error])
    assert_nil User.find_by_login('new_ldap_user')
  end

  test 'should create omni authenticated user' do
    # change the setting
    Seek::Config.omniauth_enabled       = true
    Seek::Config.omniauth_user_create   = true
    Seek::Config.omniauth_user_activate = false
    @request.env['omniauth.auth'] = OmniAuth.config.mock_auth[:ldap]

    post :create
    assert_redirected_to login_path
    assert_match(/You still need to activate your account. A validation email should have been sent to you./, flash[:error])
    new_user = User.find_by_login('new_ldap_user')
    assert_not_nil new_user
    assert !new_user.active?
    assert_equal OmniAuth.config.mock_auth[:ldap][:info]['email'], new_user.person.email
    assert_equal 1, Person.where(first_name: 'new', last_name: 'ldap_user').count
  end

  test 'should create and activate omni authenticated user' do
    # change the setting
    Seek::Config.omniauth_enabled       = true
    Seek::Config.omniauth_user_create   = true
    Seek::Config.omniauth_user_activate = true
    @request.env['omniauth.auth'] = OmniAuth.config.mock_auth[:ldap]

    post :create
    assert_redirected_to root_path
    assert_match(/You have successfully logged in, New Ldap_user./, flash[:notice])
    new_user = User.find_by_login('new_ldap_user')
    assert_not_nil new_user
    assert new_user.active?
    assert !Person.where(first_name: 'new', last_name: 'ldap_user').empty?
  end

  protected

  def cookie_for(user)
    users(user).remember_token
  end
end
