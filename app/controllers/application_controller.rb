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
    # Nevermind, we want it for CINS too
    # Screw it, we'll generalize it out to an environment variable

    if(ENV['proxy_images'].blank? || ENV['proxy_images'].downcase != 'true')
      render plain: "Proxy images not enabled for this installation: proxy_images=#{ENV['proxy_images']}"
      return
    end

    url = params['url']
    
    # For Newscoop, the images are returned as an API call, not a permalink. It's not smart, but it's what they do.
    if ENV['cms_mode'] == "newscoop"
      url += "&ImageHeight=#{params['ImageHeight']}" if !params['ImageHeight'].nil?
      url += "&ImageWidth=#{params['ImageWidth']}" if !params['ImageWidth'].nil?
      url += "&ImageId=#{params['ImageId']}" if !params['ImageId'].nil?
    end
    
    if(allow_to_proxy?(url))
      image_response = Rails.cache.fetch(url, expires_in: 5.minutes) do
        logger.info("URL requested not cached: #{url}")
        logger.info("Fetching #{url}")
        raw_response = HTTParty.get(url)
        image_response = {body: raw_response.body, content_type: raw_response.headers['content-type']}
        image_response
      end
      
      send_data image_response[:body], type: image_response[:content_type], disposition: 'inline', layout: false
    else
      render plain: "Error retreiving #{url}, the host does not match any allowed uris."
      return
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
      when "cins-codeigniter"
        @cms_mode = :cins_codeigniter
      when "blox"
        @cms_mode = :blox
      else
        raise "CMS type #{ENV['cms_mode']} not valid for this version of Push."
    end
  end

  def cms_url
    case ENV['cms_mode']
    when "occrp-joomla"
      url = ENV['occrp_joomla_url']
    when "wordpress"
      url = ENV['wordpress_url']
    when "newscoop"
      url = ENV['newscoop_url']
    when "cins-codeigniter"
      url = ENV['codeigniter_url']
    when "blox"
      url = ENV['blox_url']
    else
      raise "CMS type #{ENV['cms_mode']} not valid for this version of Push."
    end

    url
  end
  
  def allow_to_proxy? url
    link_uri = Addressable::URI.parse(url)
    base_uri = Addressable::URI.parse(cms_url)

    if(link_uri.host.nil?)        
      link_uri.host = base_uri.host
      link_uri.scheme = base_uri.scheme
      url = link_uri.to_s
    end

    link_host = link_uri.host.gsub('www.', '')
    base_host = base_uri.host.gsub('www.', '')
    
    logger.info("Checking for valid image proxy request #{link_host} vs. #{base_host}")
    if(link_host == base_host)
      return true
    end
    
    # We check if there's optional urls listed in the secret.env file
    
    return true if allowed_proxy_hosts().include?(link_host)
    return false
  end
  
  def allowed_proxy_hosts
    return [] unless ENV.has_key? 'allowed_proxy_subdomains'
    
    allowed_proxy_subdomains = ENV['allowed_proxy_subdomains']
    allowed_proxy_subdomains = allowed_proxy_subdomains.gsub('[', '')
    allowed_proxy_subdomains = allowed_proxy_subdomains.gsub(']', '')
    allowed_hosts = allowed_proxy_subdomains.split(',')
    allowed_hosts.map!{|host| host.gsub('"', '')}

    return allowed_hosts
  end

  def heartbeat
    # OK, this checks a bunch of stuff
    # Specifically we have to go through each language and call "articles" on it, that should be good enough for now

    categories = ['true', 'false']
    @response = []

    begin
      if ENV['languages'].nil?
        categories.each do |categorized|
          @response = sample_call nil, categorized
        end
      else
        languages = ENV['languages'].delete('"').split(',')

        # Run through each language, and each iteration of categories
        languages.each do |language|
          categories.each do |categorized|
            @response = sample_call language, categorized
          end
        end
      end
    rescue => e
      message = "Heartbeat failed: #{e}"

      if params.has_key?('v') && params['v'] == 'true'
        message += "\n\nBacktrace\n"
        message += '----------------------'
        e.backtrace.each { |line| message += "\n#{line}" }
        message += "\n----------------------\n"
      end

      logger.debug message
      render plain: message, status: 503
      return
    end

    render plain: 'Success'
  end

  def sample_call language, category
    params = {}
    params['language'] = language unless language.nil?
    params['categories'] = category unless category.nil?

    case @cms_mode
    when :occrp_joomla
      response = ArticlesController.new.get_occrp_joomla_articles(params)
    when :wordpress
      response = Wordpress.articles(params)
      # @response['results'] = clean_up_response @response['results']
    when :newscoop
      response = Newscoop.articles(params)
    when :cins_codeigniter
      response = CinsCodeigniter.articles(params)
    end

    response.to_json
  end
  
end
