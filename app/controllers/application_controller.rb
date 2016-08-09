class ApplicationController < ActionController::Base
  # Prevent CSRF attacks by raising an exception.
  # For APIs, you may want to use :null_session instead.
  protect_from_forgery with: :exception
  
  # Set the cms mode for all controller requests
  before_action :check_for_valid_cms_mode


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
      image_response = Rails.cache.fetch(url, expires_in: 5.minutes) do
        logger.info("URL requested not cached: #{url}")
        logger.info("Fetching #{url}")
        raw_response = HTTParty.get(url)
        image_response = {body: raw_response.body, content_type: raw_response.headers['content-type']}
        image_response
      end
      
      send_data image_response[:body], type: image_response[:content_type], disposition: 'inline'
    end
    
  end

  def check_for_valid_cms_mode
    @cms_mode

    logger.debug "Checking validity of #{ENV['cms_mode']}"
    case ENV['cms_mode']
      when "occrp-joomla"
        @cms_mode = :occrp_joomla
      when "wordpress"
        @cms_mode = :wordpress
      when "newscoop"
        @cms_mode = :newscoop
      when "cins-codeignitor"
        @cms_mode = :cins_codeigniter
      else
        raise "CMS type #{ENV['cms_mode']} not valid for this version of Push."
    end
  end

end
