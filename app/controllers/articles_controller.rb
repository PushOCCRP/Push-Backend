class ArticlesController < ApplicationController

  before_action :check_for_valid_cms_mode
  before_action :check_for_force_https

  @newscoop_access_token

  def index
    
    @response = []

    case @cms_mode 
      when :occrp_joomla
        @response = get_occrp_joomla_articles
      when :wordpress
        @response = get_wordpress_articles
        #@response['results'] = clean_up_response @response['results']
      when :newscoop
        @response = get_newscoop_articles
      when :cins_codeigniter
        @response = get_cins_codeigniter_articles
    end
    
    respond_to do |format|
      format.json
    end

  end

  def get_occrp_joomla_articles
    url = ENV['occrp_joomla_url'] + "&view=articles"

    version = params["v"]

    # Shortcut
    # We need the request to look like this, so we have to get the correct key.
    # At the moment it makes the call twice. We need to cache this.
    @response = Rails.cache.fetch("joomla_articles#{version}", expires_in: 1.hour) do
      request_response = HTTParty.get(url, headers: {'Cookie' => get_cookie()})
      body = response.body

      body = JSON.parse(request_response.body)
      articles = clean_up_response(body['results'])
      articles = format_occrp_joomla_articles(articles)
      {results: articles}
    end

    return @response
  end
  
  def get_cins_codeigniter_articles
    url = ENV['cins_codeignitor_url']+'/api/articles'
    language = params['language']
    if(language.blank?)
      # Should be extracted
      language = "rs"
    end

    version = params["v"]

    @response = Rails.cache.fetch("cins_codeigniter_articles/#{language}/#{version}", expires_in: 1.hour) do
      logger.info("aritcles are not cached, making call to newscoop server")
      response = HTTParty.get(url)
      body = JSON.parse response.body
      return body
    end        
  end

  def get_wordpress_articles
    language = params['language']
    if(!language.blank?)
      language = "/#{language}/"
    end

    url = ENV['wordpress_url'] 
    version = params["v"]

    final_url = "#{url}#{language}?push-occrp=true&type=articles"

    logger.debug("Retrieveing articles at: #{final_url}")
    response = HTTParty.get(final_url)
    response_json = JSON.parse(response.body)
    response_json['results'] = clean_up_response(response_json['results'])

    return response_json
  end

  def get_newscoop_articles
    access_token = get_newscoop_auth_token
    url = ENV['newscoop_url'] + '/api/articles.json'
    language = params['language']
    version = params["v"]

    if(language.blank?)
      # Should be extracted
      language = "az"
    end
    
    options = {access_token: access_token, language: language, 'sort[published]' => 'desc'}

    logger.info("Fetching articles")

    cached = true
    @response = Rails.cache.fetch("newscoop_articles/#{language}/#{version}", expires_in: 1.hour) do
      logger.info("articles are not cached, making call to newscoop server")
      cached = false
      response = HTTParty.get(url, query: options)
      body = JSON.parse response.body
      format_newscoop_response(body)
    end        

    if(cached == true)
      logger.info("Cached hit for articles")
    else
      logger.info("Cached missed")
    end
    
    return @response
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
      when :cins_codeigniter
        @response = get_cins_codeigniter_articles
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
    search_results = format_occrp_joomla_articles(search_results)
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

      language = params['language']
      if(!language.blank?)
        language = "/#{language}/"
      end

      query = params['q']
      url = "#{ENV['wordpress_url']}#{language}?push-occrp=true&type=search&q=#{query}"
      response = HTTParty.get(url)

      body = JSON.parse response.body
    
      search_results = clean_up_response(body['results'])

      @response = {query: query,
                 start_date: "19700101",
                 end_date: DateTime.now.strftime("%Y%m%d"),
                 total_results: search_results.size,
                 page: "1",
                 results: search_results
                }
      return @response
  end

  #stub this out to a specific feature
  # need to add "get articles for id list to wordpress too..."
  def search_bivol_google
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
    search_results = format_occrp_joomla_articles(search_results)
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

  def search_cins_codeigniter
    url = ENV['cins_codeigniter_url']+'api/search'
    language = params['language']
    if(language.blank?)
      # Should be extracted
      language = "rs"
    end

    version = params["v"]

    options = {q: params['q']}
    response = HTTParty.get(url, query: options)
    body = JSON.parse response.body
    formate_cins_codeigniter_response(body)
  end

  def article
    case @cms_mode
      when :occrp_joomla
        @response = get_occrp_joomla_article
      when :wordpress
        @response = get_wordpress_article
      when :newscoop
        @response = get_newscoop_article
      when :cins_codeigniter
        @response = get_cins_codeigniter_article
    end 
    
    respond_to do |format|
      format.json
    end
  end

  def get_occrp_joomla_article
    url = ENV['occrp_joomla_url'] + "&view=article&id=#{params["id"]}"

    # Shortcut
    # We need the request to look like this, so we have to get the correct key.
    # At the moment it makes the call twice. We need to cache this.
    @response = Rails.cache.fetch("joomla_article_#{params['id']}", expires_in: 1.hour) do
      request_response = HTTParty.get(url, headers: {'Cookie' => get_cookie()})
      body = response.body

      body = JSON.parse(request_response.body)
      articles = clean_up_response(body['results'])
      articles = format_occrp_joomla_articles(articles)
      {results: articles}
    end

    return @response

  end

  def get_wordpress_article

      language = params['language']
      if(!language.blank?)
        language = "/#{language}/"
      end

      article_id = params['id']
      url = "#{ENV['wordpress_url']}#{language}?push-occrp=true&type=article&article_id=#{article_id}"

      logger.debug("Fetching article id: article_id")
      logger.debug(url)

      response = HTTParty.get(url)

      body = JSON.parse response.body
    
      article_results = clean_up_response(body['results'])

      @response = {article_id: article_id,
                 start_date: "19700101",
                 end_date: DateTime.now.strftime("%Y%m%d"),
                 total_results: article_results.size,
                 page: "1",
                 results: article_results
                }
      return @response

  end

  def get_newscoop_article
    article_id = params['id']

    access_token = get_newscoop_auth_token
    url = ENV['newscoop_url'] + "/api/articles/#{article_id}.json"

    logger.debug("Calling newscoop url: ${url}")

    language = params['language']
    version = params["v"]

    if(language.blank?)
      # Should be extracted
      language = "az"
    end
    
    options = {access_token: access_token, language: language, 'sort[published]' => 'desc'}

    logger.info("Fetching article with id #{article_id}")

    cached = true
    @response = Rails.cache.fetch("newscoop_articles/#{article_id}/#{language}/#{version}", expires_in: 1.hour) do
      logger.info("article is not cached, making call to newscoop server")
      cached = false
      response = HTTParty.get(url, query: options)
      body = JSON.parse response.body
      format_newscoop_response({'items' => [body]})
    end        

    if(cached == true)
      logger.info("Cached hit for articles")
    else
      logger.info("Cached missed")
    end
    
    return @response
  end

  def get_cins_codeigniter_article
    url = ENV['cins_codeigniter_url']+'api/article'
    language = params['language']
    if(language.blank?)
      # Should be extracted
      language = "rs"
    end

    version = params["v"]
    article_id = params['id']

    @response = Rails.cache.fetch("cins_codeigniter_article/#{article_id}/#{language}/#{version}", expires_in: 1.hour) do
      options = {id: params['id']}
      logger.info("aritcles are not cached, making call to newscoop server")
      response = HTTParty.get(url, query: options)
      body = JSON.parse response.body
      return format_cins_codeignitor_response(body)
    end        
  end

  private
  
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

  def check_for_force_https
    @force_https
    if(ENV['force_https'])
      case ENV['force_https']
        when 'false'
          @force_https = false
        when 'true'
          @force_https = true
        else
          raise "Unacceptable value for 'force_https'"
      end
    else
      @force_https = false
    end
  end
  
  def get_cookie
    #change to the environment variable
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
      article['images'] = []
      article['image_urls'] = []
      elements = Nokogiri::HTML article['body']
      elements.css('img').each do |image|
        image_address = image.attributes['src'].value
        if !image_address.starts_with?("http")
          # Obviously needs to be fixed
          full_url = base_url + "/" + image.attributes['src'].value

          image_object = {url: full_url, caption: "", width: "", height: "", byline: ""}
          article['images'] << image_object

          article['image_urls'] << full_url
        else
          if(@force_https)
            uri = Addressable::URI.parse(image_address)
            uri.scheme = 'https'
            image_address = uri.to_s
          end

          image_object = {url: image_address, caption: "", width: "", height: "", byline: ""}
          article['images'] << image_object
        end

        # This is a filler for the app itself. Which will replace the text with the images 
        # (order being the same as in the array)
        # for versioning we put this in
        multiple_image_version_required = 1.1

        if(params["v"] && params["v"].to_f >= multiple_image_version_required)
          image.replace("^&^&")
        else
          image.remove
        end
      end

      article['body'] = elements.to_html

      if(@cms_mode == :wordpress)
        article['body'] = scrubWordpressTagsFromHTMLString article['body']
        article['body'] = cleanUpNewLines article['body']
        article['body'] = scrubScriptTagsFromHTMLString article['body']
        article['body'] = scrubJSCommentsFromHTMLString article['body']
        article['body'] = scrubSpecialCharactersFromSingleLinesInHTMLString article['body']
        article['body'] = scrubHTMLSpecialCharactersInHTMLString article['body']
        article['headline'] = HTMLEntities.new.decode(article['headline'])
      end

      # Just in case the dates are improperly formatted
      # Cycle through options
      published_date = nil
      begin
        published_date = DateTime.strptime(article['publish_date'], '%F %T')
      rescue => error
      end

      if(published_date.nil?)
        begin
          published_date = DateTime.strptime(article['publish_date'], '%Y%m%d')
        rescue => error
        end
      end

      if(published_date.nil?)
        published_date = DateTime.new(1970,01,01)
      end


      # right now we only support dates on the mobile side, this will be time soon.
      article['publish_date'] = published_date.strftime("%Y%m%d")
    end

    return articles
  end

  def format_occrp_joomla_articles articles
    articles.each do |article|
      article['url'] = URI.join(base_url, article['id'])
    end
  end
  
  def format_newscoop_response body
    logger.debug("Received #{body}")
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
        formatted_article['body'] = scrubImageTagsFromHTMLString formatted_article['body']

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

  def format_cins_codeignitor_response body
    items = body['results']
    new_items = []
    items.each do |item|
      date = Date.strptime("item['publish_date']", "%Y-%m-%d %H:%M:%S")
      item['publish_date'] = date.strftime("%Y%m%d")
    end

    body['results'] = new_items

    return body
  end

  def scrubImageTagsFromHTMLString html_string
    scrubber = Rails::Html::TargetScrubber.new
    scrubber.tags = ['img', 'div']

    html_fragment = Loofah.fragment(html_string)
    html_fragment.scrub!(scrubber)
    scrubbed = html_fragment.to_s.squish.gsub(/<p[^>]*>([\s]*)<\/p>/, '')
    scrubbed.gsub!('/p>', '/p><br />')
    scrubbed.squish!
    return scrubbed
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

  #\[[A-z\s\S]+\]
  def scrubWordpressTagsFromHTMLString html_string
    scrubbed = html_string.gsub(/\[[A-z\s\S]+\]/, "")
    return scrubbed
  end
  #\/\/.+
  def scrubJSCommentsFromHTMLString html_string
    scrubbed = html_string.gsub(/\s\/\/.+/, "")
    return scrubbed
  end

  def scrubSpecialCharactersFromSingleLinesInHTMLString html_string
    scrubbed = html_string.gsub(/^[^a-z0-9]+[.\s]+/, "")
    return scrubbed
  end

  def scrubHTMLSpecialCharactersInHTMLString html_string
    scrubbed = html_string.gsub(/^&[a-z0-9]+;/, "")
  end

  def scrubScriptTagsFromHTMLString html_string
    scrubber = Rails::Html::TargetScrubber.new
    scrubber.tags = ['script']

    html_fragment = Loofah.fragment(html_string)
    scrubbed = html_fragment.scrub!(scrubber).to_s
    scrubbed = html_fragment.to_s.squish
    scrubbed.gsub!(/<p>([\s]*)/, '')
    scrubbed.gsub!(/([\s]*)<\/p>/, '')
    scrubbed.gsub!('/p>', '/p><br />')
    scrubbed.squish!

    #put back in the spacers
    scrubbed.gsub!("::::", "<br /><br />")
    return scrubbed
  end

  def scrubTargetFromHrefLinksInHTMLString html_string
    #Fail here since its not implemented!!!!
  end

  #This adds <br /> tags if necessary, originally for KRIK from Wordpress
  #This puts in :::: as place holder while we clean the rest
  def cleanUpNewLines html_string
    cleaned = html_string
    cleaned.gsub!("\r\n\r\n", "::::")
    return cleaned
  end
  
  def format_description_text text
    text = ActionView::Base.full_sanitizer.sanitize(text)
    
    if(!text.nil?)
      text.squish!
    
      if text.length > 140
        text = text.slice(0, 140) + "..."
      end
    else
      text = "..."
    end

    return text
  end
  
  def base_url
    url = nil
    case ENV['cms_mode']
      when "occrp-joomla"
        url = ENV['occrp_joomla_url']
      when "wordpress"
        url = ENV['wordpress_url']
      when "newscoop"
        url = ENV['newscoop_url']
      else
        raise "CMS type #{cms_type} not valid for this version of Push."
    end

    uri = URI.parse(url)
    url = uri.scheme + "://" + uri.host
    return url
  end
end
