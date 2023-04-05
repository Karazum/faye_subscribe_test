require "bundler"
require "bundler/setup"
require "rack/handler/puma"
require "net/http"

server_timeout = 30
Bundler.require
faye_server = Faye::RackAdapter.new(:mount => '/faye', :timeout => server_timeout, :ping => 10)
app = Rack::Builder.new
app.run faye_server

faye_server_thread = Thread.new do
  Rack::Handler::Puma.run(app, {
    Host: "0.0.0.0",
    Port: 9393,
    Threads: "4:4",
    environment: ENV.fetch("RAILS_ENV", "development"),
    logger: Logger.new(STDOUT),
    raise_exception_on_sigterm: false,
  })
end

puts "Waiting 2 seconds until server is running"
sleep 2

$web_socket_url = "http://0.0.0.0:9393/faye"

# client timeout must be bigger than server timeout
# https://faye.jcoglan.com/ruby.html
client_timeout = server_timeout + 1
client = Faye::Client.new($web_socket_url, timeout: client_timeout)

def do_sub(client, i)
  Faye.ensure_reactor_running!
  puts "Subscribing to channel #{i}"
  sub = client.subscribe("/channel/#{i}")
  sub.with_channel do |channel, message|
    puts "Got message on channel #{i}"
  end

  start_time = Time.now.to_f
  while sub.instance_variable_get(:@deferred_status) != :succeeded
    sleep 0.005
  end
  duration = Time.now.to_f - start_time
  puts "Channel #{i} subscribed in #{duration} seconds"
end

# Thread.new do
#   loop do
#     puts "Sending message to all channels"
#     (1..10).each do |i|
#       payload = {
#         channel: "/channel/#{i}",
#         data: {
#           foo: "bar"
#         },
#       }
#       Net::HTTP.post_form(URI.parse($web_socket_url), message: JSON.dump(payload))
#     end
#     sleep 5
#   end
# end
def send_message(i)
  payload = {
    channel: "/channel/#{i}",
    data: {
      foo: "bar"
    },
  }
  Net::HTTP.post_form(URI.parse($web_socket_url), message: JSON.dump(payload))
end




t1 = Thread.new do
  do_sub(client, 1)
end
sleep 3
t2 = Thread.new do
  do_sub(client, 2)
end

# TEST 1 - with no message to 2nd channel
# faye_server_thread.join


# TEST 2 - with message to 2nd channel after 3 seconds
# sleep 3
# send_message(2)
# faye_server_thread.join

# TEST 3 - with 2 messages to 2nd channel after 3 seconds
# sleep 3
# send_message(2)
# send_message(2)
# faye_server_thread.join


