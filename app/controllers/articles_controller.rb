class ArticlesController < ApplicationController

  before_action :check_for_valid_cms_mode

  @newscoop_access_token

  def index
    
    @response = []
    
    case @cms_mode 
      when :occrp_joomla
        @response = get_occrp_joomla_articles
      when :wordpress
        url = ENV['wordpress_url'] 

        response = HTTParty.get(url, headers: {'Cookie' => get_cookie()})
        body = response.body

        @response = JSON.parse(response.body)
    
        #@response['results'] = clean_up_response @response['results']
      when :newscoop
        @response = get_newscoop_articles
    end
    
    respond_to do |format|
      format.json
    end

  end

  def get_occrp_joomla_articles
    url = ENV['occrp_joomla_url']

    # Shortcut
    # We need the request to look like this, so we have to get the correct key.
    # At the moment it makes the call twice. We need to cache this.
    @response['results'] = Rails.cache.fetch("joomla_articles", expires_in: 1.hour) do
      response = HTTParty.get(url, headers: {'Cookie' => get_cookie()})
      body = response.body

      @response = JSON.parse(response.body)
      clean_up_response @response['results']
    end

    return @response
  end
  
  def get_newscoop_articles
    access_token = get_newscoop_auth_token
    url = ENV['newscoop_url'] + '/api/articles.json'
    language = params['language']
    if(language.blank?)
      # Should be extracted
      language = "az"
    end
    
    options = {access_token: access_token, language: language, 'sort[published]' => 'desc'}

    @response = Rails.cache.fetch("newscoop_articles/#{language}", expires_in: 1.hour) do
      logger.info("aritcles are not cached, making call to newscoop server")
      response = HTTParty.get(url, query: options)
      body = JSON.parse response.body
      format_newscoop_response(body)
    end        
    
  end
  
  def get_newscoop_auth_token
    Newscoop.instance.access_token
  end
  
  def search
    case @cms_mode
      when :occrp_joomla
        @response = search_occrp_joomla
      when :wordpress
        @response = search_wordpress
      when :newscoop
        @response = search_newscoop
    end 
    
    respond_to do |format|
      format.json
    end
  end

  def search_occrp_joomla
    url = ENV['occrp_joomla_url']

    query = params['q']
    # Get the search results from Google
    url = "https://www.googleapis.com/customsearch/v1?key=AIzaSyCahDlxYxTgXsPUV85L91ytd7EV1_i72pc&cx=003136008787419213412:ran67-vhl3y&q=#{query}"
    response = HTTParty.get(url)
    # Go through all the responses, and then make a call to the Joomla server to get all the correct responses
    url = "https://www.occrp.org/index.html?option=com_push&format=json&view=urllookup&u="
    @response = {items: []}
    links = []
    response['items'].each do |result|
      url << URI.encode(result['link'])
      if result != response['items'].last
        url << ","
      end
    end

    response = HTTParty.get(url, headers: {'Cookie' => get_cookie()})

    # Turn all the responses into something that looks nice and is expected
    search_results = clean_up_response JSON.parse(response.body)
    @response = {query: query,
                 start_date: "19700101",
                 end_date: DateTime.now.strftime("%Y%m%d"),
                 total_results: search_results.size,
                 page: "1",
                 results: search_results
                }

    return @response
  end
  
  def search_wordpress
      @response = {query: query,
                 start_date: "19700101",
                 end_date: DateTime.now.strftime("%Y%m%d"),
                 total_results: search_results.size,
                 page: "1",
                 results: search_results
                }
      return @response
  end
  
  def search_newscoop
    query = params['q']

    access_token = get_newscoop_auth_token
    url = ENV['newscoop_url'] + '/api/search/articles.json'
    language = params['language']
    if(language.blank?)
      language = "az"
    end
    
    options = {access_token: access_token, language: language, query: query}        
    response = HTTParty.get(url, query: options)
    body = JSON.parse response.body
    
    @response = format_newscoop_response(body)
  end

  private
  
  def check_for_valid_cms_mode
    @cms_mode
    cms_mode = ENV['cms_mode']
    case cms_mode
      when "occrp-joomla"
        @cms_mode = :occrp_joomla
      when "wordpress"
        @cms_mode = :wordpress
      when "newscoop"
        @cms_mode = :newscoop
      else
        raise "CMS type #{cms_type} not valid for this version of Push."
    end
  end
  
  def get_cookie
    url = "https://www.occrp.org/index.html?option=com_push&format=json&view=urllookup&u="
    response = HTTParty.get(url)
    cookies = response.headers['set-cookie']
    correct_cookie = nil
    cookies.split(', ').each do |cookie|
      if cookie.include? "[lang]"
        return cookie
        break
      end
    end

    return nil
  end

  def clean_up_response articles
    articles.delete_if{|article| article['headline'].blank?}
    articles.each do |article|
      # If there is no body (which is very prevalent in the OCCRP data for some reason)
      # this takes the intro text and makes it the body text
      if article['body'].nil? || article['body'].empty?
        article['body'] = article['description']
      end
      # Limit description to number of characters since most have many paragraphs

      article['description'] = format_description_text article['description']

      # Extract all image urls in the article and put them into a single array.
      article['image_urls'] = []
      elements = Nokogiri::HTML article['body']
      elements.css('img').each do |image|
        image_address = image.attributes['src'].value
        if !image_address.starts_with?("http")
          # Obviously needs to be fixed
          article['image_urls'] << "https://www.occrp.org/" + image.attributes['src'].value
        else
          article['image_urls'] << image_address
        end
      end

      # Just in case the dates are improperly formatted
      begin
        published_date = DateTime.strptime(article['publish_date'], '%F %T')
      rescue => error
        published_date = DateTime.new(1970,01,01)
      end

      # right now we only support dates on the mobile side, this will be time soon.
      article['publish_date'] = published_date.strftime("%Y%m%d")
    end

    return articles
  end
  
  def format_newscoop_response body
    response = {}
    response['start_date'] = nil
    response['end_date'] = nil
    response['total_items'] = body['items'].count
    response['page'] = 1
    response['results'] = format_newscoop_articles(body['items'])
    return response
  end
  
  def format_newscoop_articles articles
    formatted_articles = []
    articles.each do |article|
        formatted_article = {}
        formatted_article['headline'] = article['title']
        formatted_article['description'] = format_description_text article['fields']['deck']
        formatted_article['body'] = article['fields']['full_text']
        if(article['authors'] && article['authors'].count > 0)
          formatted_article['author'] = article['authors'][0]['name']
        end
      
        formatted_article['publish_date'] = article['published'].to_time.to_formatted_s(:number_date)
        # yes, they really call the id 'number'
        formatted_article['id'] = article['number']
        formatted_article['language'] = article['languageData']['RFC3066bis']
      
        videos = []
        
        if(!article['fields']['youtube_shortcode'].blank?)
            youtube_shortcode = article['fields']['youtube_shortcode']
            youtube_id = extractYouTubeIDFromShortcode(youtube_shortcode)
            
            videos << {youtube_id: youtube_id}
        end
              
        formatted_article['videos'] = videos
        
        images = []
        
        if(article['renditions'].count > 0 && !article['renditions'][0]['details']['original'].blank?)
            preview_image_url = "https://" + URI.unescape(article['renditions'][0]['details']['original']['src'])
            passthrough_image_url = passthrough_url + "?url=" + URI.escape(preview_image_url)
            caption = article['renditions'][0]['details']['caption']
            width = article['renditions'][0]['details']['original']['width']
            height = article['renditions'][0]['details']['original']['height']
            byline = article['renditions'][0]['details']['photographer']
            image = {url: passthrough_image_url, caption: caption, width: width, height: height, byline: byline}
            images << image
        end
        
        formatted_article['images'] = images
        formatted_article['url'] = article['url']
        formatted_articles << formatted_article
    end
    
    return formatted_articles
  end
  
  def extractYouTubeIDFromShortcode shortcode
    if(shortcode.downcase.start_with?('http://youtu.be', 'https://youtu.be'))
      shortcode.sub!('http://youtu.be/', '')
      shortcode.sub!('https://youtu.be/', '')
      
      id = shortcode
      return id      
    end
    
    return nil
  end
  
  def format_description_text text
    text = ActionView::Base.full_sanitizer.sanitize(text).squish
    if text.length > 140
      text = text.slice(0, 140) + "..."
    end
    return text
  end
  
end
