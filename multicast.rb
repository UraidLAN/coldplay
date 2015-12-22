require 'ipaddr'
require 'socket'
require 'net/http'

s = UDPSocket.open
MCA = "239.0.0.1"
MCP = 3300
m = IPAddr.new(MCA).hton + IPAddr.new("0.0.0.0").hton
s.setsockopt(:IPPROTO_IP, :IP_ADD_MEMBERSHIP, m)
s.setsockopt(:SOL_SOCKET, :SO_REUSEPORT, 1)
s.bind("0.0.0.0", MCP)
loop do
  mess, _ = s.recvfrom(1024)
  Net::HTTP.post_form(URI.parse('http://127.0.0.1:3000/c/put'), {'json'=>mess})
end
