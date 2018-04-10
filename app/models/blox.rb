class Blox < CMS

	def self.articles params
    results = Rails.cache.fetch("articles", expires_in: 1.hour) do
      get_articles
    end    
    
    response = {start_date: "19700101",
           end_date: DateTime.now.strftime("%Y%m%d"),
           total_results: results.size,
           page: "1",
           results: results
          }

    return response
	end

	def self.article params
	end

	def self.search params
	end
	
	def self.authenticate user_name, password, params
    url = get_url "/user/authenticate/"
    
    body = {'user' => user_name, 'password' => password}
    headers = {'Accept' => 'application/json', 'Content-Type'  => 'application/x-www-form-urlencoded'}
    response = HTTParty.post(url, body: body, headers: headers, basic_auth: auth_credentials(:user))
    body = JSON.parse response.body

    # Check if we authenticated properly
    # {"code"=>0, "status"=>"error", "message"=>"Invalid password or account does not exist"}
    return false if body['code'] == 0 && body['status'] == 'error'

    # {"id"=>"91776626-faf4-11e7-9740-5cb9017bb5c0", "screen_name"=>"cguess", "screenname"=>"cguess", "authtoken"=>"0bef3508-0d21-11e8-bab0-5cb9017b3637", "avatar_url"=>"https://secure.gravatar.com/avatar/716725aebaee97a244ce88b27c296de9?s=100&d=mm&r=g", "avatarurl"=>"https://secure.gravatar.com/avatar/716725aebaee97a244ce88b27c296de9?s=100&d=mm&r=g", "services"=>[], "auth_assertion_url"=>"https://www.columbiamissourian.com/tncms/auth/assert/?token=d6bu5L9NtERytnV9wQ1IstsUr9bhAmvI9Btlu5kXz43CMYkUbI4jOJyp25KwOWuTtB8wzlh2XXKjrS814XC0kF%2Fbf%2BUPaXXktAFD3Q%2BnLSddjQPg%2BWlZkghy78P1wxev7vsIA7K1sNZWT9yjAhymkNqDHUaLj3d0cCfyQq0pGgIq6runWQ7jaLDenCN8qNoxAZrGe2Tf%2FkImD%2B9CBIFiP%2BEyxmqWa4%2BW"}
    return true
  end

	private

	def self.get_url path
		url = ENV['blox_url']
		url += "/" unless url[-1] == "/"
		url += "tncms/webservice/v1" 
		url += "/" unless path[0] == "/"
		url += path
    return url
	end

	def self.get_articles version = 1
		# Blox is very odd in it's structure. It bases its entire system
		# off of the publishing style of physical newspapers. So there are
		# publications, editions, pages. The pages each has various elements
		# the CMS even includes positioning information, which... fine?
		# The problem is that this means a lot of calls to pull everything in.
		
		# Instead of the system above we're going to try something a bit different.
		# Here we'll use the "search" function to pull everything.
		# 1.) Use the categories API to get categories for display. If there's nothing selected... get them all?
		# 2.) Run a search through each category. Get the first ten "articles".
		# 3.) Get details on each article
		# 4.) Retreive images for each article.
		# 5.) Right now we'll just use the top one. Unless there's some way to indicate positioning.
		# 6.) Cache this because otherwise... dear god.
		# 7.) Set up a timer to somehow do this every two minutes or so to seed the cache.

    categories = get_categories
    assets = {}
    categories.each{|category| assets[category] = get_articles_for_category(category)} 
		
		articles = {}
		assets.each do |key, assets_array|
   		articles[key] = []

  		assets_array['items'].each do |asset|
    		article = get_asset(asset)    		
    		articles[key] << article
      end

      puts("^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^")
      puts(articles[key][0]) 
      puts("^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^")
    end
    
#		articles = clean_up_response(articles)
#    return articles
    
    formatted_categories = {}
    
		articles.each do |key, category|
  		formatted_categories[key] = []
  		formatted_categories[key] = category.map do |article|

    		byline = article['byline']
    		content = article['content'].join("")
    		
    		content = scrubScriptTagsFromHTMLString(content)
    		content = scrubJSCommentsFromHTMLString(content)
        content = normalizeSpacing(content)
        
        byline = ' ' if byline.nil?
        
    		formatted_article = {
      		'author' => byline,
      		'publish_date' => article['start_time'],
          'headline' => article['title'],
      		'body' => content
    		}
        
        clean_up_byline(formatted_article)
    		formatted_article
      end
      formatted_categories[key] = clean_up_response(formatted_categories[key])
      formatted_categories.delete(key) if formatted_categories[key].empty?
    end

		return formatted_categories
	end
	
  def self.get_categories
    cache = true;
    cached_categories = Rails.cache.fetch("categories", expires_in: 1.hour) do
      cache = false;
                  
	    url = get_url "/editorial/categories/"
	    
	    response = HTTParty.get(url, basic_auth: auth_credentials(:editorial))
	    body = JSON.parse response.body

	    # Since the array returned is all of what we're looking for, we just return it.
	    return body
	  end
    
    logger.debug("get_categories #{params.to_s} Cache hit") if cache == true
    logger.debug("get_categories #{params.to_s} Cache missed") if cache == false
  
	  return cached_categories
  end
  
  def self.get_articles_for_category category
    cache = true;
    cached_articles = Rails.cache.fetch("articles_#{category}", expires_in: 1.minutes) do
      cache = false;
                  
      params = {
        'l': 10,
        'sd': 'desc',
        'c[]': "#{category}*",
        't': 'article'
      }
	    url = get_url "/editorial/search/"
	    
	    response = HTTParty.get(url, basic_auth: auth_credentials(:editorial), query: params)
	    body = JSON.parse response.body

	    # Since the array returned is all of what we're looking for, we just return it.
	    return body
	  end
    
    logger.debug("get_categories #{params.to_s} Cache hit") if cache == true
    logger.debug("get_categories #{params.to_s} Cache missed") if cache == false
  
	  return cached_categories

  end
	
	def self.parse_page json
		return unless json.has_key?('json_url')

		url = json['json_url']

		cached_assets = Rails.cache.fetch("page/#{url}", expires_in: 1.hour) do
      cache = false;
            	    
	    response = HTTParty.get(url, basic_auth: auth_credentials)
	    body = JSON.parse response.body

	    assets = []

	    segments = body['segments']
	    segments.each do |segment|
	    	asset = segment['asset']
	    	next unless asset['type'] == 'article'
	    	page_asset = {}
	    	page_asset['uuid'] = asset['uuid']
	    	page_asset['prologue'] = asset['prologue']
	    	page_asset['body'] = asset['content'].join(' ')
	    	assets << page_asset
	    end

	    # Since the array returned is all of what we're looking for, we just return it.
#   		cleaned_articles = clean_up_response(articles)
	    return assets
	  end
    
    logger.debug("page #{url} Cache hit") if cache == true
    logger.debug("page #{url} Cache missed") if cache == false

    return cached_assets
 	end
 	
 	def self.get_article_asset page_asset
    cache = true;
    cached_asset = Rails.cache.fetch("article/#{page_asset['id']}", expires_in: 1.hour) do
      cache = false;
            
      asset = get_asset page_asset
      
      article = {}
      article['body'] = page_asset['body']
      article['description'] = page_asset['prologue']
      article['headline'] = asset['title']
      article['author'] = asset['byline']
      article['publish_date'] = Date.parse(asset['update_time']).strftime("%Y%m%d")
      article['language'] = default_language()
      article['id'] = asset['id']
      article['url'] = asset['url']

      # Now we go through any images attached to the story, adding them to the object

      article['images'] = asset['relationships']['child'].select{|image_asset|
            image_asset['asset_type'] == 'image'
          }.map{|image_asset|
            get_image_asset(image_asset)
          }
      
      article['captions'] = article['images'].map{|image| image['caption']}
      article['photoBylines'] = article['images'].map{|image| image['byline']}
	    return article
	  end
	      
    logger.debug("get_asset #{page_asset['uuid']} Cache hit") if cache == true
    logger.debug("get_asset #{page_asset['uuid']} Cache missed") if cache == false
  
    return cached_asset
  end
  
  def self.get_image_asset page_asset
    cache = true;
    cached_asset = Rails.cache.fetch("image/#{page_asset['id']}", expires_in: 1.hour) do
      cache = false;
            
      asset = get_asset page_asset
      image = {}      
      image['url'] = asset['resource_url']
      image['caption'] = asset['content'].nil? ? "" : clean_up_image_caption(asset['content'].join(' '))
      image['byline'] = clean_up_image_caption(asset['byline'])
      image['id'] = asset['id']
      image['date'] = Date.parse(asset['update_time'])
#      image = CMS.rewrite_image_url(image)
	    return image
	  end
	      
    logger.debug("get_asset #{page_asset['uuid']} Cache hit") if cache == true
    logger.debug("get_asset #{page_asset['uuid']} Cache missed") if cache == false
  
    return cached_asset
  end

  def self.get_asset page_asset
    id = page_asset['id'].blank? ? page_asset['uuid'] : page_asset['id']
    return Rails.cache.fetch("editorial/get/#{id}", expires_in: 1.hour) do
  	  url = get_url "editorial/get/?id=#{id}"
	    response = HTTParty.get(url, basic_auth: auth_credentials(:editorial))
	    body = JSON.parse response.body
	    return body
	  end
  end


	def self.make_request url
		logger.debug("Making request to #{url}")
  	response = HTTParty.get(URI.encode(url), basic_auth: auth_credentials)
    
    begin
	    body = JSON.parse response.body
	  rescue => exception
      logger.debug "Exception parsing JSON from CMS"
      logger.debug "Statement returned"
      logger.debug "---------------------------------------"
      logger.debug response.body
      logger.debug "---------------------------------------"
      raise
    end
	  return body
	end
	
	def self.clean_up_byline article
  	article['author'].gsub!("By", "")
  	article['author'].gsub!("by", "")
  	article['author'].gsub!("BY", "")
  	article['author'].gsub!("\\n", "")
  	article['author'].strip!
  end
  
  def self.clean_up_image_caption caption
    caption.gsub!("<p>", '')
    caption.gsub!("</p>", '')
    # Yes, I know, never use regex on html, but it's just comments and only used in very small instances
    caption.gsub!(/(?=<!--)([\s\S]*?)-->/, '')
    return caption
  end
  	

  # options are :eedition and :editorial
	def self.auth_credentials service=:eedition
    return case service
      when :eedition then {:username => ENV['blox_eedition_key'], :password => ENV['blox_eedition_secret']}
      when :editorial then {:username => ENV['blox_editorial_key'], :password => ENV['blox_editorial_secret']}
      when :user then {:username => ENV['blox_user_key'], :password => ENV['blox_user_secret']}
      else raise "Unsupported credentials type #{service}."
    end
	end

end