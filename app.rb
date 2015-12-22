require 'bundler'
Bundler.require

require 'tilt/erb'
require 'net/ssh'
require 'net/scp'

# load the Database and User model
require './model'

# ssh lol

class Coldplay < Sinatra::Base
  enable :sessions
  # THIS IS IMPORTANT! NOT SPECIFYING THIS WILL BREAK SESSIONS!!!!
  # https://www.youtube.com/watch?v=OBwS66EBUcY -- culex found and fixed
  set :session_secret, '!NU3uu8inlktthvlrugnivngjrdldueit'
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
      action: 'a/noauth'
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

  # def admin_auth(user, level)
  # end

  before do
    @user = env['warden'].user || nil
  end

  ## Index(-chan)

  get '/' do
    erb :index
  end

  ## Warden / User Login/out

  get '/a' do
    if @user.nil?
      redirect '/a/login'
    else
      redirect '/'
    end
  end

  get '/a/login' do
    erb :'auth/login' 
  end

  post '/a/login' do
    env['warden'].authenticate! :password

    flash[:success] = env['warden'].message

    if session[:return_to].nil?
      redirect '/'
    else
      redirect session[:return_to]
    end
  end

  get '/a/logout' do
    env['warden'].logout
    flash[:success] = 'Successfully logged out'
    redirect '/'
  end

  post '/a/noauth' do
    session[:return_to] = env['warden.options'][:attempted_path] if session[:return_to].nil?
    puts env['warden.options'][:attempted_path]
    puts env['warden']
    flash[:error] = env['warden'].message || "You must log in"
    redirect '/a/login'
  end

  # Card Management

  get '/c' do
    redirect '/'
  end

  post '/c/put' do
    if request.ip == "127.0.0.1"
      j = JSON.parse(params[:json])
      if j["event"] == "exitButton"
        Log.create(event: "exitButton")
      elsif j["event"] == "unknownCard"
        Log.create(event: "unknownCard", cid: j["id"])
      elsif j["event"] == "doorUnlock"
        Log.create(event: "doorUnlock", cid: j["id"], user: j["user"])
      elsif j["event"] == "disabledCard"
        Log.create(event: "disabledCard", cid: j["id"], user: j["user"])
      end
    end
  end

  get '/c/list' do
    if @user.nil?
      flash[:error] = env['warden'].message || "You must log in"
      redirect '/a/login'
    end
    db = Sequel.connect('sqlite://cards.db')
    @cards = db.fetch("SELECT * FROM rfid ORDER BY username,description DESC")
    erb :'card/list'
  end

  get '/c/logs' do
    if @user.nil?
      flash[:error] = env['warden'].message || "You must log in"
      redirect '/a/login'
    end
    @logs = Log.all
    erb :'card/logs'
  end

  get '/c/add' do
    if @user.nil?
      flash[:error] = env['warden'].message || "You must log in"
      redirect '/a/login'
    end
    @prefill = nil
    erb :'card/add'
  end

  get '/c/add/:cid' do
    if @user.nil?
      flash[:error] = env['warden'].message || "You must log in"
      redirect '/a/login'
    end
    @prefill = params[:cid]
    erb :'card/add'
  end

  post '/c/add' do
    if @user.nil?
      flash[:error] = env['warden'].message || "You must log in"
      redirect '/a/login'
    end
    db = Sequel.connect('sqlite://cards.db')
    if params["card"].empty?
      flash[:error] = "Something went wrong~!"
      env['REQUEST_METHOD'] = 'GET'
      redirect '/c/add'
    end

    if params["card"]["cid"].upcase.length != 8
      flash[:error] = "Not a card ID"
      redirect '/c/add'
    end
    dataset = db["INSERT INTO rfid (card_id,username,enabled,soundfile,description) VALUES (?,?,1,'',?)", params["card"]["cid"].upcase, params['card']['user'], params["card"]["ctype"]]
    dataset.insert
    flash[:success] = "Card added, remember to <a href='/s/sync'>sync</a>!"
    redirect '/c/add'
  end

  # anything in /s is an ssh runner, yay

  get '/s/sync' do
    Net::SSH.start('doorpi', 'root', keys: "/home/peer/.ssh/id_rsa") do |ssh|
      puts 'SSH: Connected'
      puts 'SSH: SCP Start'
      ssh.scp.upload!("/home/peer/coldplay/cards.db", "/home/pi/overlook/cards.db") do |ch, name, sent, total|
        puts "SSH: SCP: #{sent}/#{total}"
      end
      puts 'SSH: SCP Done'
      channel = ssh.open_channel do |ch|
        ch.exec "pkill -9 doorlock.py" do |ch, success|
          raise "RemoteCommandError" unless success
          ch.on_close { puts "SSH: OVERLOOK Restarted" }
        end
      end
      puts "SSH: Closed"
    end
    erb :'meta/10sec'
  end


end
