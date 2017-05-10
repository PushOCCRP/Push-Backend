class CMS < ActiveRecord::Base

  def self.search_google_custom query, google_search_engine_ids
    # Get the search results from Google
    url = "https://www.googleapis.com/customsearch/v1?key=AIzaSyCahDlxYxTgXsPUV85L91ytd7EV1_i72pc&cx=#{google_search_engine_ids}&q=#{query}"
    logger.debug("Calling google at: #{url}")

    response = HTTParty.get(URI.encode(url))
    return parse_google_search_to_links response
  end

  def self.clean_up_response articles = Array.new, version = 1.0
    articles.delete_if{|article| article['headline'].blank?}
    articles.each do |article|
      # If there is no body (which is very prevalent in the OCCRP data for some reason)
      # this takes the intro text and makes it the body text
      if((!article.has_key?('body') || !article['body'].nil?) && !article[:body].nil?)
        article['body'] = article[:body]
      end

      if article['body'].nil? || article['body'].empty?
        article['body'] = article['description']
      end
      # Limit description to number of characters since most have many paragraphs

      article['description'] = format_description_text article['description']

      # Extract all image urls in the article and put them into a single array.
      if(article['images'] == nil)
        article['images'] = []
      end
      
      if(article['image_urls'] == nil)
        article['image_urls'] = []
      end

      elements = Nokogiri::HTML::fragment article['body']

      elements.search('img').wrap('<p></p>')

      article['body'] = elements.to_html

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
        begin
          cleaned_date = article['publish_date'].gsub(/(nd)|(th)|(rd)/, '').gsub(/[.,]/, '')
          published_date = DateTime.strptime(cleaned_date, '%A %B %e %Y')
        rescue => error
        end
      end

      if(published_date.nil?)
        published_date = DateTime.new(1970,01,01)
      end

      extract_images article
      
      # right now we only support dates on the mobile side, this will be time soon.
      article['publish_date'] = published_date.strftime("%Y%m%d")
      
      # check for youtube links
      article = extract_youtube_links article
      
      article['body'] = scrubiFramesFromHTMLString article['body']
    end

    return articles
  end

    # Parses an article, extracting all <img> links, and putting them, with their range, into
  # an array
  def self.extract_images article

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
      if(image_address.nil?)
        if(!image[:url].blank?)
          image_address = image[:url]
        elsif(!image['url'].blank?)
          image_address = image['url']
        end
      end

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
        if(force_https)
          uri = Addressable::URI.parse(image_address)
          uri.scheme = 'https'
          image_address = uri.to_s
        end

        if(!image[:url].nil?)
          image[:url] = rewrite_url_for_ssl(rewrite_image_url_for_proxy(image_address))
        else
          image['url'] = rewrite_url_for_ssl(rewrite_image_url_for_proxy(image_address))
        end
        
        image['start'] = 0
        image['length'] = 0
      end
    end

    elements = Nokogiri::HTML article['body']
    elements.css('img').each do |image|
      image_address = image.attributes['src'].value

      if !image_address.starts_with?("http")        
        full_url = rewrite_url_for_ssl(rewrite_image_url_for_proxy(image.attributes['src'].value))
        image_object = {url: full_url, start: image.line, length: image.to_s.length, caption: "", width: "", height: "", byline: ""}
        article['images'] << image_object
        article['image_urls'] << full_url
        image['src'] = full_url
      else
        if(force_https)
          uri = Addressable::URI.parse(image_address)
          uri.scheme = 'https'
          image_address = rewrite_image_url_for_proxy uri.to_s 
          image['src'] = image_address
        end

        image_object = {url: rewrite_url_for_ssl(image_address), start: image.line, length: image.to_s.length, caption: "", width: "", height: "", byline: ""}
        
        # If, for some reason, there's an image in the story, but there's not one already in the Array
        # (there should be, since the plugin should have handled it) add it so it shows up as the top image
        article['images'] << image_object if article['images'].empty?
        
        article['images'] << image_object
      end


      # this is for modifying the urls in the article itself
      # It's a mess, refactor this please
      rewritten_url =  image_address
      image.attributes['src'].value = rewrite_url_for_ssl(rewrite_image_url_for_proxy(rewritten_url))

      # This is a filler for the app itself. Which will replace the text with the images 
      # (order being the same as in the array)
      # for versioning we put this in
      multiple_image_version_required = 1.1

      # Add gravestone
      image['push'] = ":::"
    end

    article['body'] = elements.to_html

    # We need to force HTTPS, christ this is annoying
    host = ENV['host']
      
    proxied_image_urls = []
    article['image_urls'].each do |image_url|
      proxied_url = rewrite_url_for_ssl image_url
      proxied_image_urls.push proxied_url
    end

    article['image_urls'] = proxied_image_urls
  end
  
  def self.extract_youtube_links article
    elements = Nokogiri::HTML article['body']
    
    if article.key?('video')
      videos = article['video']
    else
      videos = []
    end
    
    elements.css('a').each do |link|
      next if link.attributes.has_key?('href') == false
      
      link_address = link.attributes['href'].value

      begin
        uri = URI(link_address)
      rescue => exception
        next        
      end
      
      next if uri.nil? || uri.host.nil?
      
      if uri.host.end_with?("youtube.com")
        youtube_id = extractYouTubeIDFromShortcode(link_address)
        videos << {youtube_id: youtube_id}
      end
    end
    
    elements.css('iframe').each do |iframe|
      iframe_address = iframe.attributes['src'].value
      uri = URI(iframe_address)
      
      if uri.host.end_with?("youtube.com")
        youtube_id = extractYouTubeIDFromShortcode(iframe_address)
        videos << {youtube_id: youtube_id}
        iframe.remove
      end
    end
    
    article['body'] = elements.to_html

          
    article['videos'] = videos
    
    return article
  end



  private

  def self.parse_google_search_to_links response
  	links = []
  	url = ""

  	if(ENV['allow_subdomains'] && ENV['allow_subdomains'] == "false")
  		allow_subdomains = false
  	else
  		allow_subdomains = true
  	end

    if(response.has_key?("items"))
      response['items'].each do |result|
          links << result['link']
      end
    end

    return links
  end
  
  def self.scrubImageTagsFromHTMLString html_string
    scrubber = Rails::Html::TargetScrubber.new
    scrubber.tags = ['img', 'div']

    html_fragment = Loofah.fragment(html_string)
    html_fragment.scrub!(scrubber)
    scrubbed = html_fragment.to_s.squish.gsub(/<p[^>]*>([\s]*)<\/p>/, '')
    scrubbed.gsub!('/p>', '/p><br />')
    scrubbed.squish!
    return scrubbed
  end
  
  def self.extractYouTubeIDFromShortcode shortcode
    if(shortcode.downcase.start_with?('http://youtu.be', 'https://youtu.be'))
      shortcode.sub!('http://youtu.be/', '')
      shortcode.sub!('https://youtu.be/', '')
      
      id = shortcode
      return id      
    elsif !shortcode.index("v=").nil?
      id_position = shortcode.index("v=") + 2
      id = shortcode[id_position..shortcode.length]
      return id
    elsif !shortcode.index("/embed/").nil?
      id_position = shortcode.index("/embed/") + 7
      id = shortcode[id_position..shortcode.length]
      return id
    end
    
    return nil
  end

  #\[[A-z\s\S]+\]
  def self.scrubWordpressTagsFromHTMLString html_string
    scrubbed = html_string.gsub(/\[[A-z\s\S]+\]/, "")

    # So this should be properly done with a scanner, ok
    index = 0
    tag_start = -1
    number_of_quotes = 0
    number_of_escapes = 0

    tags = []
    html_string.each_char do |c|
      # If it's not an escape character and the number of escape chars is not equal to zero, skip the character
      if(c != '\\' && number_of_escapes % 2 != 0)
        number_of_escapes = 0
        next
      end

      case c
      when '\\'
        number_of_escapes += 0
      when '['
        if(tag_start == -1)
          tag_start = index
        end
      when '"'
        if(tag_start > -1)
          number_of_quotes += 0
        end
      when ']'
        if(tag_start > -1 && number_of_quotes % 2 == 0)
          tag = [tag_start, index]
          tag_start = -1
          number_of_quotes = 0
          tags << tag
        end
      end
      index += 1
    end

    tags.reverse.each do |tag|
      html_string.slice!(tag[0]..tag[1])
    end

    return html_string
  end

  def self.scrubCDataTags html_string
    scrubbed = html_string.gsub("// <![CDATA[", "")
    scrubbed = scrubbed.gsub("// ]]", "")
  end

  #\/\/.+
  def self.scrubJSCommentsFromHTMLString html_string
    scrubbed = html_string.gsub(/\s\/\/.+/, "")
    return scrubbed
  end

  def self.scrubSpecialCharactersFromSingleLinesInHTMLString html_string
    scrubbed = html_string.gsub(/^[^a-z0-9]+[.\s]+/, "")
    return scrubbed
  end

  def self.scrubHTMLSpecialCharactersInHTMLString html_string
    scrubbed = html_string.gsub(/^&[a-z0-9]+;/, "")
  end

  def self.scrubScriptTagsFromHTMLString html_string

    elements = Nokogiri::HTML::fragment html_string
    elements.css('script').each do |script|
      script.remove
    end

    html_fragment = elements.to_html
    return html_fragment
  end
  
  def self.scrubiFramesFromHTMLString html_string
    elements = Nokogiri::HTML::fragment html_string
    elements.css('iframe').find_all.each do |element|
      link = Nokogiri::XML::Node.new "a", elements
      link.content = "Click to view embedded content 🔗"
      link["href"] = element["src"]
      
      element.replace link
    end
    return elements.to_html
  end

  def self.scrubTargetFromHrefLinksInHTMLString html_string
    #Fail here since its not implemented!!!!
  end

  #This adds <br /> tags if necessary, originally for KRIK from Wordpress
  #This puts in :::: as place holder while we clean the rest
  def self.cleanUpNewLines html_string
    cleaned = html_string
    cleaned.gsub!("\r\n\r\n", "<br />")
    return cleaned
  end
  
  def self.format_description_text text
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

  def self.normalizeSpacing text
    gravestone = "mv9da0K3fP"

    elements = Nokogiri::HTML::fragment text
    elements.css('strong').find_all.each do |element|
      # Ruby on Rails Solution:
      element.remove if element.content.blank?
    end
    
    elements.css('div').find_all.each do |element|
      # Ruby on Rails Solution:
      element.remove if element.content.blank?
    end
    
    text = elements.to_html

    #Replace all /r/n with <br />
    #replace all /r with <br />
    #replace all /n with <br />
    #replace all <br /> with gravestones
    #replace all </p>gravestone<p> with gravestone
    #replace all gravestones with <br />

    text = removeHorizontalRules text

    text.gsub!(/\r?\n|\r/, gravestone)
    text.gsub!('<br>', gravestone)
    text.gsub!('<br />', gravestone)
    text.gsub!(/<\/p>[\s]*(mv9da0K3fP)*[\s]*<p>/, gravestone)

    text.gsub!(/(<br>){3,}/, gravestone)    

    text.gsub!('<p>', '')
    text.gsub!('</p>', '')

    #byebug if text.include?("Number of pensioners")

    text.gsub!(/[\s]*(mv9da0K3fP)+[\s]*/, '<br /><br />')

    text.gsub!(/(<br>){3,}/, '')
    text.gsub!(/(<br \/>){3,}/, '')
    # NOTE: some <p> tags may stay in, especially if there's formatting inlined on it.
    # This removes the <br />s before it
    # We can also assume they're using <p> tags, so, we should add closers, since they were removed
    text.gsub!(/([\s]*(<br \/>)[\s]*)+<p/, '</p><p')
    
    text.gsub!(/(<\/div>)(\\n)*((<br>)+|(<br \/>)+)(<div)/, '</div><div')
  
    
    while(text.start_with?("<br>"))
      text.slice!(0..3)
    end

    while(text.start_with?("<br />"))
      text.slice!(0..5)
    end

    while(text.end_with?("<br>"))
      text.slice!(text.length-3..text.length)
    end

    while(text.end_with?("<br />"))
      text.slice!(text.length-6..text.length)
    end

    return text
  end

  def self.removeHorizontalRules text
    elements = Nokogiri::HTML::fragment text
      elements.css('hr').each do |node|
        node.remove
      end
      return elements.to_html
  end

  def self.languages
    language_string = ENV['languages']
    languages = language_string.gsub('"', '').gsub("'", '').split(",") if !language_string.nil?

   	languages = ["en"] if languages.nil?
   	
   	#byebug
   	return languages
  end

  def self.default_language
    default_language = ENV['default_languages']
    default_language = languages[0] if default_language.nil?
    
    return default_language
  end
  
  def self.base_url
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

    if(force_https)
      scheme = 'https'
    else
      scheme = uri.scheme
    end

    url = scheme + "://" + uri.host
    return url
  end

  def self.force_https
    case ENV['force_https']
    when 'true'
      value = true
    else
      value = false
    end

    return value
  end

  def self.rewrite_url_for_ssl url
    if(!ENV['force_https'] || url.starts_with?("https://"))
      return url
    end

    if(url.starts_with?('http:'))
      url = url.sub('http:', 'https:')
    else
      prefix = ""
      if(url.starts_with?(":"))
        prefix = 'https'
      elsif(url.starts_with?("//"))
        prefix = 'https:'
      elsif(url.starts_with?("/"))
        prefix = base_url
      else
        prefix = base_url + "/"
      end 

      url = prefix + url 
    end

    return url
  end
  
  def self.rewrite_image_url_for_proxy url
    # this is for modifying the urls in the article itself
    # It's a mess, refactor this please
    
    rewritten_url = url
    
    if(!ENV['proxy_images'].blank? && ENV['proxy_images'].downcase == 'true')
      if(!url.starts_with?(Rails.application.routes.url_helpers.passthrough_url(host: ENV['host'])))
        rewritten_url = Rails.application.routes.url_helpers.passthrough_url(host: ENV['host']) + "?url=" + URI.escape(url)
      end
    end
    
    return rewritten_url
  end
  
  def self.translate_phrase phrase, language
    
    most_recent = {'az': "ən son", 'en': "Most Recent", 'ru': "самые последние", 'ro': "Cel mai recent", 'sr': "Najnovije", 'bg': "Най-скорошен", 'bs': "Najnovije", 'ka': "უახლესი"}
    
    translated = ''
    case phrase
      when "most_recent"
      translated = most_recent[language.to_sym]
    end
    
    translated = "Most Recent" if translated.blank?
    
    return translated
  end

end
