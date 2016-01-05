class ApplicationController < ActionController::Base
  # Prevent CSRF attacks by raising an exception.
  # For APIs, you may want to use :null_session instead.
  protect_from_forgery with: :exception
  
  #This is just a passthrough for basic GET commands. Takes a URL, calls it, and returns the body.
  #This should conceivably cache responses at some point
  #Should also require auth token
  def passthrough
    url = params['url']
    response = HTTParty.get(url)
    render text: response, content_type: response.headers['content-type']
  end
end
