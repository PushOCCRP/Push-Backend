class CMS < ActiveRecord::Base

  def self.search_google_custom query, google_search_engine_ids
    # Get the search results from Google
    url = "https://www.googleapis.com/customsearch/v1?key=AIzaSyCahDlxYxTgXsPUV85L91ytd7EV1_i72pc&cx=#{google_search_engine_ids}&q=#{query}"
    logger.debug("Calling google at: #{url}")

    response = HTTParty.get(url)
    return parse_google_search_to_links response
  end

  def self.clean_up_response articles = Array.new, version = 1.0
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
      if(article['images'] == nil)
        article['images'] = []
      end
      
      if(article['image_urls'] == nil)
        article['image_urls'] = []
      end

      elements = Nokogiri::HTML::fragment article['body']
      elements.css('img').each do |image|
        image_address = image.attributes['src'].value
        if !image_address.starts_with?("http")
          # Obviously needs to be fixed
          full_url = base_url + "/" + image.attributes['src'].value

          image_object = {url: full_url, caption: "", width: "", height: "", byline: ""}
          article['images'] << image_object

          article['image_urls'] << full_url
        else
          if(force_https)
            uri = Addressable::URI.parse(image_address)
            uri.scheme = 'https'
            image_address = uri.to_s
            image['src'] = image_address
          end

          image_object = {url: image_address, caption: "", width: "", height: "", byline: ""}
          article['images'] << image_object
        end

        # This is a filler for the app itself. Which will replace the text with the images 
        # (order being the same as in the array)
        # for versioning we put this in
        # multiple_image_version_required = 1.1

        # if(version >= multiple_image_version_required)
        #  image.replace("^&^&")
        # else
        #  image.remove
        # end

        image['push'] = ":::"
      end


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
        published_date = DateTime.new(1970,01,01)
      end

      # There's an interesting bug where the images coming back from a plugin
      # may not be https, so if we're forcing, we'll fix that here
      if(force_https)
        article['images'].each do |image|
          if(image[:url] == nil)
            url = image["url"]
          else
            url = image[:url]
          end

          if(!url.starts_with? "https")
            uri = Addressable::URI.parse(url)
            uri.scheme = 'https'
            image['url'] = uri.to_s
          end
        end
      end

      # right now we only support dates on the mobile side, this will be time soon.
      article['publish_date'] = published_date.strftime("%Y%m%d")
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

        image['url'] = full_url
        image['start'] = 0
        image['length'] = 0
      end
    end

    elements = Nokogiri::HTML article['body']
    elements.css('img').each do |image|
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
        image['href'] = full_url
      else
        if(force_https)
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

  def self.scrubTargetFromHrefLinksInHTMLString html_string
    #Fail here since its not implemented!!!!
  end

  #This adds <br /> tags if necessary, originally for KRIK from Wordpress
  #This puts in :::: as place holder while we clean the rest
  def self.cleanUpNewLines html_string
    byebug
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
  
  def self.base_url
    url = nil
    case ENV['cms_mode']
      when "occrp-joomla"
        url = ENV['occrp_joomla_url']
      when "wordpress"
        url = ENV['wordpress_url']
      when "newscoop"
        url = ENV['newscoop_url']
      when "cins-codeignitor"
        url = ENV['cins_codeignitor_url']
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
end