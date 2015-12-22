require 'bcrypt'

## Warden/DataMapper setup, our other databases will be Sequel

DataMapper.setup(:default, "sqlite://#{Dir.pwd}/db.sqlite")

class User
  include DataMapper::Resource
  include BCrypt

  property :id, Serial, key: true
  property :username, String, length: 128
  property :admin, Integer, default: 0

  property :password, BCryptHash

  def authenticate(attempted_password)
    if self.password == attempted_password
      true
    else
      false
    end
  end
end

class Log
  include DataMapper::Resource

# "{\"event\": \"exitButton\"}"
# "{\"event\": \"unknownCard\", \"id\": \"88041E1B\"}"
# "{\"id\": \"8804565B\", \"label\": \"myki\", \"event\": \"doorUnlock\", \"user\": \"rails\"}"

  property :id, Serial, key: true
  property :ts, DateTime, :default => lambda { |r, p| DateTime.now }
  property :event, String, required: true, unique: false
  property :cid, String, required: false, unique: false
  property :user, String, required: false, unique: false

end

# Tell DataMapper the models are done being defined
DataMapper.finalize

# Update the database to match the properties of User.
DataMapper.auto_upgrade!

# Create a test User
if User.count == 0
  @user = User.create(username: "admin")
  @user.password = "balls"
  @user.admin = 100
  @user.save
end