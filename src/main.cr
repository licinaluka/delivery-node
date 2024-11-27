require "http/client"
require "kemal"
require "kemal-session"
require "uri"

token = nil
ads = [] of String

# api = URI.parse "https://microads.ix.tc"
api = URI.parse "http://localhost:3000"
client = HTTP::Client.new api

port_lo = 49_152
port_hi = 65_535
                                              
hostname = "http://localhost"
port = (port_lo .. port_hi).to_a.shuffle.first
uri = [hostname, port].join(":")

Kemal::Session.config.secret = "_super_secret_"

get "/" do |env|
  ENV["CLAIM_CODE"] ||= "none"
  code = ENV["CLAIM_CODE"]
  "This is a delivery-node for microads.ix.tc, identifier: #{code}"
end

get "/ad" do |env|
  if ads.empty?
    puts "Fetching more ads."
    limit = 10
    client.before_request do |req|
      req.headers["Authorization"] = "Bearer #{token}"
    end
    res = client.get "/ads/batch?limit=#{10}"

    if ! [200].includes? res.status_code
      client.post "/api/ads/delivery-nodes?uri=#{uri}", form: ""
    end
    ads.concat res.body.split("\n\n")
  end

  ads.shuffle!
  ad = ads.shift(1)
  env.response.print ad.first
end

get "/registered" do |env|
  nonce = env.params.query["nonce"]
  raise "Nonce missing!" if nonce.nil?

  res = client.get "/api/ads/delivery-node/verify?uri=#{uri}&nonce=#{nonce}"
  token = res.headers["token"]
  
  puts "Registered! New secret #{token[-25..]} (use to create free ads)"
end

get "/health/ready" do
end

get "/health/live" do
  true
end

puts "Self registering to #{api}..."
client.post "/api/ads/delivery-nodes?uri=#{uri}", form: ""

puts "Trying port #{port}..."
Kemal.config.port = port
Kemal.run
