require 'bundler'
Bundler.require

# load the Database and User model
require './model'

class WebInterface < Sinatra::Base
  enable :sessions
  # THIS IS IMPORTANT! NOT SPECIFYING THIS WILL BREAK SESSIONS!!!!
  # https://www.youtube.com/watch?v=OBwS66EBUcY -- culex found and fixed
  set :session_secret, 'ANR328fnA"+/(t'
  register Sinatra::Flash

  use Warden::Manager do |config|
    # Tell Warden how to save our User info into a session.
    # Sessions can only take strings, not Ruby code, we'll store
    # the User's `id`
    config.serialize_into_session{|user| user.id }
    # Now tell Warden how to take what we've stored in the session
    # and get a User from that information.
    config.serialize_from_session{|id| User.get(id) }

    config.scope_defaults :default,
      # "strategies" is an array of named methods with which to
      # attempt authentication. We have to define this later.
      strategies: [:password],
      # The action is a route to send the user to when
      # warden.authenticate! returns a false answer. We'll show
      # this route below.
      action: 'auth/unauthenticated'
    # When a user tries to log in and cannot, this specifies the
    # app to send the user to.
    config.failure_app = self
  end

  Warden::Manager.before_failure do |env,opts|
    env['REQUEST_METHOD'] = 'POST'
  end

  Warden::Strategies.add(:password) do
    def valid?
      params['user'] && params['user']['username'] && params['user']['password']
    end

    def authenticate!
      user = User.first(username: params['user']['username'])

      if user.nil?
        fail!("The username you entered does not exist.")
      elsif user.authenticate(params['user']['password'])
        success!(user)
      else
        fail!("Could not log in")
      end
    end
  end

  def admin_auth(user, level)

  ## Index(-chan)

  get '/' do
    @user = env['warden'].user || nil
    erb :index
  end

  ## Warden / User Login/out

  get '/auth' do
    if @user = env['warden'].user == nil
      redirect '/auth/login'
    else
      redirect '/'
    end
  end

  get '/auth/login' do
    @user = env['warden'].user || nil
    erb :'auth/login' 
  end

  post '/auth/login' do
    env['warden'].authenticate! :password
    @user = env['warden'].user || nil

    flash[:success] = env['warden'].message

    if session[:return_to].nil?
      redirect '/'
    else
      redirect session[:return_to]
    end
  end

  get '/auth/logout' do
    env['warden'].raw_session.inspect
    env['warden'].logout
    flash[:success] = 'Successfully logged out'
    redirect '/'
  end

  post '/auth/unauthenticated' do
    session[:return_to] = env['warden.options'][:attempted_path] if session[:return_to].nil?
    puts env['warden.options'][:attempted_path]
    puts env['warden']
    flash[:error] = env['warden'].message || "You must log in"
    redirect '/auth/login'
  end

end
