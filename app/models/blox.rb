class Blox < CMS

	def self.articles params
    results, categories = Rails.cache.fetch("articles", expires_in: 1.hour) do
      get_articles
    end    
    
    response = {start_date: "19700101",
           end_date: DateTime.now.strftime("%Y%m%d"),
           total_results: results.size,
           page: "1",
           results: results,
           categories: categories
          }
    
    return response
	end

	def self.article params
  	asset = get_asset({'id' => params['id']})
  	article = format_article(asset)
    response = {start_date: "19700101",
     end_date: DateTime.now.strftime("%Y%m%d"),
     total_results: "1",
     page: "1",
     results: [article]
    }
  
    return response
	end

	def self.search params
    cache = true;
    cached_articles = Rails.cache.fetch("search_#{params['q']}", expires_in: 1.minutes) do
      cache = false;
                  
      params = {
        'l': 10,
        'sd': 'desc',
        'q': params['q'],
        't': 'article'
      }
	    url = get_url "/editorial/search/"
	    
	    response = HTTParty.get(url, basic_auth: auth_credentials(:editorial), query: params)
	    body = JSON.parse response.body
      articles = articles_from_assets(body['items'])
      articles = articles.map{|article| format_article(article)}
	    # Since the array returned is all of what we're looking for, we just return it.
	    articles
	  end
    
    logger.debug("search #{params['q']} Cache hit") if cache == true
    logger.debug("search #{params['q']} Cache missed") if cache == false
    
    response = {start_date: "19700101",
     end_date: DateTime.now.strftime("%Y%m%d"),
     total_results: cached_articles.count,
     page: "1",
     results: cached_articles
    }

	end
	
	def self.categories
  	categories = {en: get_categories}
    return categories
 	end
	
	def self.authenticate user_name, password, params
    url = get_url "/user/authenticate/"
    
    body = {'user' => user_name, 'password' => password}
    headers = {'Accept' => 'application/json', 'Content-Type'  => 'application/x-www-form-urlencoded'}
    response = HTTParty.post(url, body: body, headers: headers, basic_auth: auth_credentials(:user))
    body = JSON.parse response.body

    # Check if we authenticated properly
    # {"code"=>0, "status"=>"error", "message"=>"Invalid password or account does not exist"}
    return false if (body['code'] == 0 && body['status'] == 'error') #|| body['services'].count < 1
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

		categories_string = Setting.categories
  	most_recent_articles = nil
  	
  	YAML.load(Setting.category_names)
  	if(!categories_string.blank? && Setting.consolidated_categories.blank?)
  		categories = YAML.load(categories_string)['en']
#       if(!Setting.consolidated_categories)
#         options[:categorized]='true'
#       end
    else
      categories = get_categories
    end

    category_names = YAML.load(Setting.category_names)
    
    cached_articles = Rails.cache.fetch("articles_#{categories.join('_')}", expires_in: 5.minutes) do

      assets = {}
      categories.each{|category| assets[category] = get_articles_for_category(category)} 

  		articles = {}
  		assets.each do |key, assets_array|
    		index = assets.keys.index(key)
    		key = category_names['en'][index] if index < category_names['en'].count
    		
    		# We want to use the customized name if there is one.
     		articles[key] = articles_from_assets(assets_array['items'])
      end
      
      formatted_categories = {}
      
  		articles.each do |key, category|
    		formatted_categories[key] = []
    		formatted_categories[key] = category.map{|article| format_article(article)}
        
        # We need to rearrange articles per category so an article with an image is going to be at top
        formatted_categories.keys.each do |key|
          formatted_categories[key] = rearrange_articles_for_images(formatted_categories[key]) 
        end
        
        formatted_categories[key] = clean_up_response(formatted_categories[key])
        formatted_categories.delete(key) if formatted_categories[key].empty?
      end
            
      formatted_categories
    end
        
    categories = category_names['en'].reject{|name| name.empty?} unless category_names['en'].empty?
		return cached_articles, categories
	end
	
	def self.articles_from_assets assets
  	articles = []
  	assets.each do |asset|
  		article = get_asset(asset) 
	    article['description'] = asset['summary']  
  		articles << article
    end
    return articles
  end
	
	def self.format_article article
 		byline = article['byline']
		content = article['content'].join("")
		      		
		content = scrubScriptTagsFromHTMLString(content)
		content = scrubJSCommentsFromHTMLString(content)
    content = normalizeSpacing(content)
    content = clean_up_paragraphs(content)
    
    byline = ' ' if byline.nil?
    
    
    images = article['images'].map do |image|
      {'url' => image['url'], 'caption' => "#{image['caption']} #{image['byline']}"}
    end
    
		formatted_article = {
  		'author' => byline,
  		'publish_date' => Date.parse(article['start_time']).strftime("%Y%m%d"),
      'headline' => article['title'],
      'description' => article['description'],
  		'body' => content,
  		'images' => images,
  		'id' => article['id'],
  		'url' => article['url']
		}
    
    clean_up_byline(formatted_article)
		formatted_article

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
	    body
	  end
    
    logger.debug("get_categories #{category.to_s} Cache hit") if cache == true
    logger.debug("get_categories #{category.to_s} Cache missed") if cache == false
    
	  return cached_articles

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
	    assets
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
	    article
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

	    image
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
	    article = JSON.parse response.body	    

 	    article['images'] = []

		    #Run through the relationships
	    if article['relationships'].key?('child')

  	    article['relationships']['child'].each do |relationship|
    	    # Right now we relationship handle images, add more here if we need to
    	    next unless relationship['asset_type'] == 'image'
          image = get_image_asset(relationship)
          article['images'] << image
        end
  	  end

	    article
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
	  body
	end
	
	def self.clean_up_byline article
  	article['author'].gsub!("By", "")
  	article['author'].gsub!("by", "")
  	article['author'].gsub!("BY", "")
  	article['author'].gsub!("\\n", "")
  	article['author'].strip!
  end
  
  def self.clean_up_image_caption caption
    return '' if caption.nil?
    caption.gsub!("<p>", '')
    caption.gsub!("</p>", '')
    # Yes, I know, never use regex on html, but it's just comments and only used in very small instances
    caption.gsub!(/(?=<!--)([\s\S]*?)-->/, '')
    caption
  end
  
  def self.clean_up_paragraphs text
    text.gsub! '<br><br>', '<br><br><br><br>'
    text.gsub! '<br/><br/>', '<br/><br/><br/><br/>'
    text.gsub! '<br /><br />', '<br /><br /><br /><br />'    
    return text
  end
  	
  # Rearrange articles so the first has an image. If none do, then return the original array	
  def self.rearrange_articles_for_images articles
    article_with_image = articles.find{|article| article['images'].count > 0}
    
    #Because I'm a good CS student I make sure we don't do unncessary array modification
    return articles if article_with_image.nil? || article_with_image == articles.first
        
    articles.delete(article_with_image)
    articles.unshift(article_with_image)
    
    return articles
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