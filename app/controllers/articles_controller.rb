class ArticlesController < ApplicationController

  before_action :check_for_force_https
  before_action :register_consumer_event
  before_action :check_api_key
  
  def index
    
    @response = []

    case @cms_mode 
      when :occrp_joomla
        @response = JoomlaOccrp.articles(params)
      when :wordpress
        @response = Wordpress.articles(params)
        #@response['results'] = clean_up_response @response['results']
      when :newscoop
        @response = Newscoop.articles(params)
      when :cins_codeigniter
        @response = CinsCodeigniter.articles(params)
      when :blox
        @response = Blox.articles(params)
      when :drupal
        @response = Drupal.articles(params)
    end
    
    respond_to do |format|
      format.json
    end

  end

  
    
  def search
    case @cms_mode
      when :occrp_joomla
        @response = search_occrp_joomla
      when :wordpress
        @response = Wordpress.search(params)
      when :newscoop
        @response = Newscoop.search(params)
      when :cins_codeigniter
        @response = CinsCodeigniter.search(params)
      when :blox
        @response = Blox.search(params)
      when :drupal
        #@response = Drupal.search(params)
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
    
  def article
    case @cms_mode
      when :occrp_joomla
        @response = JoomlaOccrp.article(params)
      when :wordpress
        @response = Wordpress.article(params)
      when :newscoop
        @response = Newscoop.article(params)
      when :cins_codeigniter
        @response = CinsCodeigniter.article(params)
      when :blox
        @response = Blox.article(params)
      when :drupal
        @response = Drupal.article(params)
    end 
    
    respond_to do |format|
      format.json
    end
  end

  

  private

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
  
  def register_consumer_event
    return if !request.env['HTTP_USER_AGENT'].blank? && request.env['HTTP_USER_AGENT'].include?('ApacheBench')
    return if !params.key? 'installation_uuid'  
      
    # Save this record to our analytic tracking  
    consumer = Consumer.find_or_create_by(uuid: params['installation_uuid'])
    consumer.times_seen += 1
    consumer.save!
    
    event = ConsumerEvent.new(consumer: consumer)
    event.language = (params.key?('language') && !params['language'].empty?) ? params['language'] : CMS.default_language
    event.event_type_id = case params['action']
    when 'index'
      ConsumerEvent::EventType::ARTICLES_LIST
    when 'article'
      event.article_id = params['id'] if params.key?('id') && !params['id'].empty?
      ConsumerEvent::EventType::ARTICLE_VIEW
    when 'search'
      event.search_phrase = params['q'] if params.key?('q') && !params['q'].empty?
      ConsumerEvent::EventType::SEARCH
    else
      return
    end
    
    event.save!
  end
  
  def check_api_key
    # first check if the setup has login enabled
    auth = true
    auth = false unless ENV.has_key?('auth_enabled') && ENV['auth_enabled'] == "true"
    
    return if auth == false
    
    # if there's nothing passed in, kill it with fire
    auth = false unless params.has_key?('api_key') && params['api_key'].empty? == false
    if auth == false
      render json: return_error("No api_key specified but authentication is enabled on this installation.")
      return
    end
    
    # if there's no user with this then also return false
    auth = false unless SubscriptionUser.exists?(api_key: params['api_key'])
    
    if auth == false
      render json: return_error("Invalid api_key")
      return
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

      extract_images article

      #article['body'] = elements.to_html

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

  # Parses an article, extracting all <img> links, and putting them, with their range, into
  # an array
  def extract_images article

    # Extract all image urls in the article and put them into a single array.
    if(article['images'] == nil)
      article['images'] = []
    end
    
    if(article['image_urls'] == nil)
      article['image_urls'] = []
    end

    #Yes, i'm aware this is repetitive code.
    article['images'].each do |image|
      image_address = image['url']

      if !image_address.starts_with?("http")
        # build up missing parts
        prefix = ""
        if(image_address.starts_with?(":"))
          prefix = 'https'
        elsif(image_address.starts_with?("//"))
          prefix = 'https:'
        elsif(image_address.starts_with?("/"))
          prefix = base_url
        else
          prefix = base_url + "/"
        end  
        # Obviously needs to be fixed
        full_url = prefix + image_address

        image['url'] = full_url
        image['start'] = 0
        image['length'] = 0

        article['image_urls'] << full_url
      else
        if(@force_https)
          uri = Addressable::URI.parse(image_address)
          uri.scheme = 'https'
          image_address = uri.to_s
        end

        image['url'] = full_url
        image['start'] = 0
        image['length'] = 0
      end
    end

    elements = Nokogiri::HTML article['body']
    images_array = elements.css('img')
    images_array.each do |image|
      image_address = image.attributes['src'].value

      if !image_address.starts_with?("http")
        # build up missing parts
        prefix = ""
        if(image.attributes['src'].value.starts_with?(":"))
          prefix = 'https'
        elsif(image.attributes['src'].value.starts_with?("//"))
          prefix = 'https:'
        elsif(image.attributes['src'].value.starts_with?("/"))
          prefix = base_url
        else
          prefix = base_url + "/"
        end  
        # Obviously needs to be fixed
        full_url = prefix + image.attributes['src'].value

        image_object = {url: full_url, start: image.line, length: image.to_s.length, caption: "", width: "", height: "", byline: ""}
        article['images'] << image_object

        article['image_urls'] << full_url
        
        if(image == images_array.first)
          image.remove
        end

        image['href'] = full_url
      else
        if(@force_https)
          uri = Addressable::URI.parse(image_address)
          uri.scheme = 'https'
          image_address = uri.to_s
          image['href'] = image_address
        end

        image_object = {url: image_address, start: image.line, length: image.to_s.length, caption: "", width: "", height: "", byline: ""}
        article['images'] << image_object
      end


      # This is a filler for the app itself. Which will replace the text with the images 
      # (order being the same as in the array)
      # for versioning we put this in
      multiple_image_version_required = 1.1

      # Add gravestone
      image['push'] = ":::"
    end

    article['body'] = elements.to_html

  end

  def format_occrp_joomla_articles articles
    articles.each do |article|
      article['url'] = URI.join(base_url, article['id'])
      article['body'] = CMS.normalizeSpacing article['body']
    end

    CMS.clean_up_response articles
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
      when "cins-codeigniter"
        url = ENV['codeigniter_url']
      else
        raise "CMS type #{cms_type} not valid for this version of Push."
    end

    logger.debug("parsing #{url}")
    uri = URI.parse(url)
    url = uri.scheme + "://" + uri.host
    return url
  end
end
