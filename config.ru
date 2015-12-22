# config.ru

require './app'
require './multicast'

child = Process.fork do
  mclisten()
end

run Coldplay