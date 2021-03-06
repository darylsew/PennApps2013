require 'sinatra'
require 'redis'
require 'json'

redis = Redis.new
#set :port, 80
#set :bind, '0.0.0.0'

# Begin https://gist.github.com/j05h/673425
class Numeric
  def to_rad
    self * Math::PI / 180
  end
end

# http://www.movable-type.co.uk/scripts/latlong.html
# loc1 and loc2 are arrays of [latitude, longitude]
def distance loc1, loc2
  lat1, lon1 = loc1
  lat2, lon2 = loc2
  dLat = (lat2-lat1).to_rad;
  dLon = (lon2-lon1).to_rad;
  a = Math.sin(dLat/2) * Math.sin(dLat/2) +
    Math.cos(lat1.to_rad) * Math.cos(lat2.to_rad) *
    Math.sin(dLon/2) * Math.sin(dLon/2);
  c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1-a));
  d = 6371 * c; # Multiply by 6371 to get Kilometers
end
# End Gist

get '/users' do
  content_type :json
  unless params[:lat] and params[:lon] and params[:radius]
    return {success: false}.to_json
  end
  lat = params[:lat]
  lon = params[:lon]
  radius = params[:radius]
  users_in_radius = []
  all_user_ids = redis.keys 'user:*'
  all_user_ids.each do |id|
    user_data = redis.hmget id, 'lat', 'lon', 'last_updated'
    user = {lat: user_data[0], lon: user_data[1], last_updated: user_data[2]}
    dist = distance [lat.to_f, lon.to_f], [user[:lat].to_f, user[:lon].to_f]
    if dist < radius.to_f
      user[:id] = id[5..-1]
      users_in_radius << user
    end
    puts "Dist: #{dist}"
  end
  {success: true, users_in_radius: users_in_radius}.to_json
end

get '/user/:id' do
  content_type :json
  id = "user:#{params[:id]}"
  unless redis.exists id
    return {success: false}.to_json
  end
  user_data = redis.hmget id, 'lat', 'lon', 'last_updated'
  user = {lat: user_data[0], lon: user_data[1], last_updated: user_data[2], id: params[:id]}
  {success: true, user: user}.to_json
end

put '/user/:id' do
  content_type :json
  id = "user:#{params[:id]}"
  unless params[:lat] and params[:lon]
    return {success: false}.to_json
  end
  lat = params[:lat]
  lon = params[:lon]
  last_updated = Time.now.to_i
  redis.hmset id,
    'lat', lat,
    'lon', lon,
    'last_updated', last_updated
  {success: true}.to_json
end

get '/user/:id/fb_access_token' do
  content_type :json
  id = "user:#{params[:id]}"
  token = redis.hget id, 'fb_access_token'
  unless token
    return {success: false}.to_json
  end
  {success: true, token: token}.to_json
end

put '/user/:id/fb_access_token' do
  content_type :json
  id = "user:#{params[:id]}"
  unless params[:token]
    return {success: false}.to_json
  end
  token = params[:token]
  redis.hset id, 'fb_access_token', token
  {success: true}.to_json
end
