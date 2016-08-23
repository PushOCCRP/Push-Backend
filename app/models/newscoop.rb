require 'singleton'
require 'resolv-replace'

class Newscoop
  @@lock = Mutex.new
  @@updated_at = nil
  @@expire_time = -1
  @@access_token = nil
  
  include Singleton

  attr_accessor :data

  def initialize
    @access_token = get_new_access_token
  end
  
  def access_token
    if(check_for_expiration)
      return get_new_access_token  
    else
      return @access_token
    end
  end
  
  def get_new_access_token
    # We don't want the access token called over and over so we lock it
    # and inform other running process not to bother if it was updated in the last second.
    # this is probably overkill
    if(!check_for_expiration)
      return @access_token
    end
    
    @@lock.synchronize {

        client_id = ENV['newscoop_client_id']
        client_secret = ENV['newscoop_client_secret']
        url = ENV['newscoop_url'] + '/oauth/v2/token'

        options = {client_id: client_id, 
                client_secret: client_secret, 
                grant_type: "client_credentials"}

        response = HTTParty.get(url, query: options)

        body = response.body

        response = JSON.parse(response.body)
        @@updated_at = Time.now.to_i
        @access_token = response['access_token']
        @@expire_time = response['expires_in']
    }
    return @access_token
  end

  def add key, value
    @data[key] = value
  end

  def version
    '0.0.1'
  end
  
  # false mean valid, true mean invalid
  private 
  def check_for_expiration
    current_time = Time.now
    # Build in a 10 second grace period
    expire_time_to_compare = @@expire_time - 10
    
    
    if(@@expire_time > -1 && 
            @@updated_at != nil && 
            current_time.since(@@updated_at).to_i < expire_time_to_compare - 10)
        return false
    end
    
    return true
  end
  
end