class ApplicationController < ActionController::Base
  # Prevent CSRF attacks by raising an exception.
  # For APIs, you may want to use :null_session instead.
  protect_from_forgery with: :exception
  
  #This is just a passthrough for basic GET commands. Takes a URL, calls it, and returns the body.
  #This should conceivably cache responses at some point
  #Should also require auth token
  def passthrough
    # We only want this to be for Newscoop
    if(ENV['newscoop_url'].blank?)
      return
    end

    url = params['url']
    link_uri = URI(url)
    base_uri = URI(ENV['newscoop_url'])
    
    if(link_uri.host == base_uri.host)
      Rails.cache.fetch("url", expires_in: 1.hour) do
        response = HTTParty.get(url)
      end
      render text: response, content_type: response.headers['content-type']
    end
    
  end
end
