class JoomlaOccrp < CMS


	def self.articles params
		cache = true;
	  cached_articles = Rails.cache.fetch("sections/#{params.to_s}", expires_in: 1.hour) do
		cache = false;
		
		  language = language_parameter params['language']
		  language = default_language if language.blank?
		raise "Requested language is not enabled"	if !languages().include?(language)
		
		  options = {}
		articles = {}
		
		  categories_string = Setting.categories
		  most_recent_articles = nil
		  
		  if(!categories_string.blank? && !params['categories'].blank? && params['categories']=='true' && Setting.consolidated_categories.blank?)
			  categories = YAML.load(categories_string)
			  categories[language] = [] if categories[language].nil?
			  options[:post_types] = categories[language].join(',')
		  if(!Setting.consolidated_categories)
			options[:categorized]='true'
		  end
		  
		  most_recent_articles_params = params.dup
		  most_recent_articles_params['categories'] = nil
		  
		  most_recent_articles = articles(most_recent_articles_params)[:results]
		  end
  
		  url = get_url language, "index.php?option=com_push&format=json&view=articles", options

		  articles = get_articles url
		  if(!most_recent_articles.nil? && !Setting.show_most_recent_articles.nil?)
		  # There maybe a bug where an array is returned, even if categories are enabled
		  if(articles[:results].is_a?(Array))
			articles[:results] = {translate_phrase("most_recent", language) => most_recent_articles}
			articles['categories'] = []
			
		  else
			  articles[:results][translate_phrase("most_recent", language)] = most_recent_articles
			end
			
			articles["categories"].insert(0, translate_phrase("most_recent", language))
		  end
		  
		  articles
	  end
	  
	  logger.debug("/articles.json #{params.to_s} Cache hit") if cache == true
	  logger.debug("/articles.json #{params.to_s} Cache missed") if cache == true
	
       


		return cached_articles
	end


	def self.language_parameter language
	    if(!language.blank?)
	      language = language
	    end

	    return language
	end

	private

	def self.get_url language, path, options = {}
		url = ENV['occrp_joomla_url'] 
		
	    
 	    url_string = "#{url}?#{path}"

	    # If there is more than one language specified (or any language at all for backwards compatibility)
	    if(languages().count > 1 && languages().include?(language))
		   url_string = "#{url}/#{language}/#{path}"
  	  end
	    
	    if(!ENV['wp_super_cached_donotcachepage'].blank?)
	    	options[:donotcachepage] = ENV['wp_super_cached_donotcachepage']
	    end

	    options.keys.each do |key|
	    	url_string += "&#{key}=#{options[key]}"
	    end

	    return url_string
	end

	def self.make_request url
		logger.debug("Making request to #{url}")
  		response = HTTParty.get(URI.encode(url))
    
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

	def self.get_articles url, extras = {},  version = 1
	    logger.debug("Calling: #{url}")

	    body = make_request url

	    if(body['results'].nil?)
	    	body['results'] = Array.new
	    end
      
	  if(body['categories'].nil?)			
		
		body['results'].each do |article|
			_, images, image_urls = self.extract_images_from_string article['description']
		#	byebug
			article['images'] = images
			article['image_urls'] = image_urls
		end

  	    results = clean_up_response(body['results'], version)
   	    results = clean_up_for_wordpress results
  	  else
  	    results = {}
  	    body['categories'].each do |category|
    	    if(body['results'][category].blank?)
      	    	results[category] = []
      	    	next
      	  	end

			body['results'][category].each do |article|

				_, images, image_urls = self.extract_images_from_string article['description']

				article['images'] = images
				article['image_urls'] = image_urls

			end


    	    results[category] = clean_up_response(body['results'][category], version)
			results[category] = clean_up_for_wordpress results[category]
			logger.debug "hello"
    	  end    	  
  	  end

	    response = {start_date: "19700101",
	               end_date: DateTime.now.strftime("%Y%m%d"),
	               total_results: results.size,
	               page: "1",
	               results: results
	              }
	   
	    response['categories'] = body['categories'] if !body['categories'].nil?

	    # add in any extras from the call, query string etc.
	    response = response.merge(extras)
	    return response
	end

	def self.language_parameter language
	    if(!language.blank?)
	      language = language
	    end

	    return language
	end

	def self.clean_up_for_wordpress articles	
		articles.each do |article|
		    article['body'] = scrubCDataTags article['body']
   		    article['body'] = scrubScriptTagsFromHTMLString article['body']
		    article['body'] = scrubWordpressTagsFromHTMLString article['body']
		    #article['body'] = cleanUpNewLines article['body']
		    article['body'] = scrubJSCommentsFromHTMLString article['body']
		    article['body'] = scrubSpecialCharactersFromSingleLinesInHTMLString article['body']
		    article['body'] = scrubHTMLSpecialCharactersInHTMLString article['body']
   		    article['body'] = normalizeSpacing article['body']

			article['headline'] = HTMLEntities.new.decode(article['headline'])

			#
			article['url'] = URI.join(base_url, article['id'])
			article['body'] = CMS.normalizeSpacing article['body']
		end

		#
		
	    return articles
	end
end
=begin  	def self.articles params
  		url = ENV['occrp_joomla_url'] + "&view=articles"
  		version = params["v"]
        # Shortcut
  		# We need the request to look like this, so we have to get the correct key.
 		# At the moment it makes the call twice. We need to cache this.
 		@response = Rails.cache.fetch("joomla_articles#{version}", expires_in: 1.hour) do
  			request_response = HTTParty.get(url)

  			body = JSON.parse(request_response.body)
 			articles = clean_up_response(body['results'])
 			articles = format_occrp_joomla_articles(articles)
  			{results: articles}
  		  end

  		 return @response
  	end
	


	 private  

	def self.format_occrp_joomla_articles articles
 		articles.each do |article|
 		  article['url'] = URI.join(base_url, article['id'])
 		  article['body'] = CMS.normalizeSpacing article['body']
 		end
 		CMS.clean_up_response articles
	 end
=end
	  



# 	def self.articles params
#  		url = ENV['occrp_joomla_url'] + "&view=articles"
#  		version = params["v"]
#        # Shortcut
#  		# We need the request to look like this, so we have to get the correct key.
#  		# At the moment it makes the call twice. We need to cache this.
#  		@response = Rails.cache.fetch("joomla_articles#{version}", expires_in: 1.hour) do
#  			request_response = HTTParty.get(url)

#  			body = JSON.parse(request_response.body)
#  			articles = clean_up_response(body['results'])
#  			articles = format_occrp_joomla_articles(articles)
#  			{results: articles}
#  		  end

#  		 return @response
#  	end



# 	def clean_up_response articles
# 		articles.delete_if{|article| article['headline'].blank?}
#  		articles.each do |article|

# 		  # If there is no body (which is very prevalent in the OCCRP data for some reason)
# 		  # this takes the intro text and makes it the body text
# 		  if article['body'].nil? || article['body'].empty?
# 			article['body'] = article['description']
# 		  end
# 		   		  # Limit description to number of characters since most have many paragraphs

# 		  article['description'] = format_description_text article['description']

# 		  extract_images article

# 		  #article['body'] = elements.to_html

# 		  if(@cms_mode == :wordpress)
# 			article['body'] = scrubWordpressTagsFromHTMLString article['body']
# 			article['body'] = cleanUpNewLines article['body']
#  			article['body'] = scrubScriptTagsFromHTMLString article['body']
#  			article['body'] = scrubJSCommentsFromHTMLString article['body']
#  			article['body'] = scrubSpecialCharactersFromSingleLinesInHTMLString article['body']
#  			article['body'] = scrubHTMLSpecialCharactersInHTMLString article['body']
#  			article['headline'] = HTMLEntities.new.decode(article['headline'])
#  		  end

#  		  # Just in case the dates are improperly formatted
#  		  # Cycle through options
#  		  published_date = nil
# 		  begin
#  			published_date = DateTime.strptime(article['publish_date'], '%F %T')
#  		  rescue => error
#  		  end

#  		  if(published_date.nil?)
#  			begin
#  			  published_date = DateTime.strptime(article['publish_date'], '%Y%m%d')
#  			rescue => error
# 			end
#  		  end

#  		  if(published_date.nil?)
#  			published_date = DateTime.new(1970,01,01)
#  		  end


#  		  # right now we only support dates on the mobile side, this will be time soon.
#  		  article['publish_date'] = published_date.strftime("%Y%m%d")
#  		end

#  		return articles
# 	end

# 	def format_occrp_joomla_articles articles
# 		 		articles.each do |article|
# 		 		  article['url'] = URI.join(base_url, article['id'])
# 		 		  article['body'] = CMS.normalizeSpacing article['body']
# 		 		end
		
# 		 		CMS.clean_up_response articles
#     end

# end


# 	def self.articles params
# 		url = ENV['occrp_joomla_url'] + "&view=articles"
# 		version = params["v"]
#       # Shortcut
# 		# We need the request to look like this, so we have to get the correct key.
# 		# At the moment it makes the call twice. We need to cache this.
# 		@response = Rails.cache.fetch("joomla_articles#{version}", expires_in: 1.hour) do
# 			request_response = HTTParty.get(url)

# 			body = JSON.parse(request_response.body)
# 			articles = clean_up_response(body['results'])
# 			articles = format_occrp_joomla_articles(articles)
# 			{results: articles}
# 		  end

# 		 return @response
# 	end





# 	  def clean_up_response articles

# 		articles.delete_if{|article| article['headline'].blank?}
# 		articles.each do |article|

# 		  # If there is no body (which is very prevalent in the OCCRP data for some reason)
# 		  # this takes the intro text and makes it the body text
# 		  if article['body'].nil? || article['body'].empty?
# 			article['body'] = article['description']
# 		  end
# 		  # Limit description to number of characters since most have many paragraphs

# 		  article['description'] = format_description_text article['description']

# 		  extract_images article

# 		  #article['body'] = elements.to_html

# 		  if(@cms_mode == :wordpress)
# 			article['body'] = scrubWordpressTagsFromHTMLString article['body']
# 			article['body'] = cleanUpNewLines article['body']
# 			article['body'] = scrubScriptTagsFromHTMLString article['body']
# 			article['body'] = scrubJSCommentsFromHTMLString article['body']
# 			article['body'] = scrubSpecialCharactersFromSingleLinesInHTMLString article['body']
# 			article['body'] = scrubHTMLSpecialCharactersInHTMLString article['body']
# 			article['headline'] = HTMLEntities.new.decode(article['headline'])
# 		  end

# 		  # Just in case the dates are improperly formatted
# 		  # Cycle through options
# 		  published_date = nil
# 		  begin
# 			published_date = DateTime.strptime(article['publish_date'], '%F %T')
# 		  rescue => error
# 		  end

# 		  if(published_date.nil?)
# 			begin
# 			  published_date = DateTime.strptime(article['publish_date'], '%Y%m%d')
# 			rescue => error
# 			end
# 		  end

# 		  if(published_date.nil?)
# 			published_date = DateTime.new(1970,01,01)
# 		  end


# 		  # right now we only support dates on the mobile side, this will be time soon.
# 		  article['publish_date'] = published_date.strftime("%Y%m%d")
# 		end

# 		return articles
# 	  end


# 	  def format_occrp_joomla_articles articles
# 		articles.each do |article|
# 		  article['url'] = URI.join(base_url, article['id'])
# 		  article['body'] = CMS.normalizeSpacing article['body']
# 		end

# 		CMS.clean_up_response articles
# 	  end

# end
# 	def self.articles params
#   	cache = true;
#     cached_articles = Rails.cache.fetch("sections/#{params.to_s}", expires_in: 1.hour) do
#       cache = false;

#     	language = language_parameter params['language']
#     	language = default_language if language.blank?
#       raise "Requested language is not enabled"	if !languages().include?(language)

#     	options = {}
#       articles = {}

#     	categories_string = Setting.categories
#     	most_recent_articles = nil

#     	if(!categories_string.blank? && !params['categories'].blank? && params['categories']=='true' && Setting.consolidated_categories.blank?)
#     		categories = YAML.load(categories_string)
#     		categories[language] = [] if categories[language].nil?
#     		options[:post_types] = categories[language].join(',')
#         if(!Setting.consolidated_categories)
#           options[:categorized]='true'
#         end

#         most_recent_articles_params = params.dup
#         most_recent_articles_params['categories'] = nil

#         most_recent_articles = articles(most_recent_articles_params)[:results]
#     	end

# 	    url = get_url "push-occrp=true&occrp_push_type=articles", language, options

# 	    articles = get_articles url
#   	  if(!most_recent_articles.nil? && !Setting.show_most_recent_articles.nil?)
#         # There maybe a bug where an array is returned, even if categories are enabled
#         if(articles[:results].is_a?(Array))
#           articles[:results] = {translate_phrase("most_recent", language) => most_recent_articles}
#           articles['categories'] = []
#         else
#   	      articles[:results][translate_phrase("most_recent", language)] = most_recent_articles
#   	    end

#   	    articles["categories"].insert(0, translate_phrase("most_recent", language))
#   	  end

#   	  articles
#     end

#     logger.debug("/articles.json #{params.to_s} Cache hit") if cache == true
#     logger.debug("/articles.json #{params.to_s} Cache missed") if cache == true

# 	  return cached_articles
# 	end

# 	def self.article params
# 	  language = language_parameter params['language']
#       article_id = params['id']
#       url = get_url "push-occrp=true&occrp_push_type=article&article_id=#{article_id}", language

#       logger.debug("Fetching article id: article_id")

#       return get_articles url
# 	end

# 	def self.search params
# 		language = language_parameter params['language']

# 	    query = params['q']

# 	    google_search_engine_id = ENV['google_search_engine_id']
# 		if(!google_search_engine_id.blank?)
# 			logger.debug "Searching google with id: #{google_search_engine_id}"
# 			articles_list = search_google_custom query, google_search_engine_id
# 			url = get_url "push-occrp=true&occrp_push_type=urllookup&u=#{articles_list.join(',')}", language
# 		else
# 		    url = get_url "push-occrp=true&occrp_push_type=search&q=#{query}", language
# 		end

# 		return get_articles url, {query: query}
# 	end

# 	def self.categories
#   	languages = languages();
#    	languages = ['en'] if(languages.nil? || languages.count == 0)


#     categories = {}

#   	languages.each do |language|
#     	# This is a temp for Kyiv Post, we need to fix the languages properly though...
#   	  response = Rails.cache.fetch("wordpress_categories_#{language}", expires_in: 1.day) do
#   			url = get_url "push-occrp=true&occrp_push_type=post_types", language
#   			logger.debug ("Fetching categories")
#   			make_request url
#   		end

# #  		byebug

# 	    if(response.class == Hash)
#         categories[language] = response.keys
#       else
#    	    categories[language] = response
#    	  end

#       categories[language] = ['post'] if(response.count == 0)
#     end




#  		return categories
# 	end



# 	private

# 	def self.get_url path, language, options = {}
# 	    url = ENV['wordpress_url']

#  	    url_string = "#{url}?#{path}"

# 	    # If there is more than one language specified (or any language at all for backwards compatibility)
# 	    if(languages().count > 1 && languages().include?(language))
#    	    url_string = "#{url}/#{language}?#{path}"
#   	  end

# 	    if(!ENV['wp_super_cached_donotcachepage'].blank?)
# 	    	options[:donotcachepage] = ENV['wp_super_cached_donotcachepage']
# 	    end

# 	    options.keys.each do |key|
# 	    	url_string += "&#{key}=#{options[key]}"
# 	    end

# 	    return url_string
# 	end

# 	def self.make_request url
# 		logger.debug("Making request to #{url}")
#   		response = HTTParty.get(URI.encode(url))

#     begin
# 	    body = JSON.parse response.body
# 	  rescue => exception
#       logger.debug "Exception parsing JSON from CMS"
#       logger.debug "Statement returned"
#       logger.debug "---------------------------------------"
#       logger.debug response.body
#       logger.debug "---------------------------------------"
#       raise
#     end
# 	  return body
# 	end

# 	def self.get_articles url, extras = {},  version = 1

# 	    logger.debug("Calling: #{url}")

# 	    body = make_request url

# 	    if(body['results'].nil?)
# 	    	body['results'] = Array.new
# 	    end

#       if(body['categories'].nil?)
#   	    results = clean_up_response(body['results'], version)
#    	    results = clean_up_for_wordpress results
#   	  else
#   	    results = {}
#   	    body['categories'].each do |category|
#     	    if(body['results'][category].blank?)
#       	    results[category] = []
#       	    next
#       	  end

#     	    results[category] = clean_up_response(body['results'][category], version)
#     	    results[category] = clean_up_for_wordpress results[category]
#     	  end
#   	  end

# 	    response = {start_date: "19700101",
# 	               end_date: DateTime.now.strftime("%Y%m%d"),
# 	               total_results: results.size,
# 	               page: "1",
# 	               results: results
# 	              }

# 	    response['categories'] = body['categories'] if !body['categories'].nil?

# 	    # add in any extras from the call, query string etc.
# 	    response = response.merge(extras)
# 	    return response
# 	end

# 	def self.language_parameter language
# 	    if(!language.blank?)
# 	      language = language
# 	    end

# 	    return language
# 	end

# 	def self.clean_up_for_wordpress articles
# 		articles.each do |article|
# 		    article['body'] = scrubCDataTags article['body']
#    		    article['body'] = scrubScriptTagsFromHTMLString article['body']
# 		    article['body'] = scrubWordpressTagsFromHTMLString article['body']
# 		    #article['body'] = cleanUpNewLines article['body']
# 		    article['body'] = scrubJSCommentsFromHTMLString article['body']
# 		    article['body'] = scrubSpecialCharactersFromSingleLinesInHTMLString article['body']
# 		    article['body'] = scrubHTMLSpecialCharactersInHTMLString article['body']
#    		  article['body'] = normalizeSpacing article['body']

# 		    article['headline'] = HTMLEntities.new.decode(article['headline'])
# 		end

# 	    return articles
# 	end














# def self.articles params
# 	cache = true;
#   cached_articles = Rails.cache.fetch("sections/#{params.to_s}", expires_in: 1.hour) do
# 	cache = false;
	
# 	  language = language_parameter params['language']
# 	  language = default_language if language.blank?
# 	raise "Requested language is not enabled"	if !languages().include?(language)
	
# 	  options = {}
# 	articles = {}
	
# 	  categories_string = Setting.categories
# 	  most_recent_articles = nil
	  
# 	  if(!categories_string.blank? && !params['categories'].blank? && params['categories']=='true' && Setting.consolidated_categories.blank?)
# 		  categories = YAML.load(categories_string)
# 		  categories[language] = [] if categories[language].nil?
# 		  options[:post_types] = categories[language].join(',')
# 	  if(!Setting.consolidated_categories)
# 		options[:categorized]='true'
# 	  end
	  
# 	  most_recent_articles_params = params.dup
# 	  most_recent_articles_params['categories'] = nil
	  
# 	  most_recent_articles = articles(most_recent_articles_params)[:results]
# 	  end

# 	  url = get_url "push-occrp=true&occrp_push_type=articles", language, options
	  
# 	  articles = get_articles url
# 	  if(!most_recent_articles.nil? && !Setting.show_most_recent_articles.nil?)
# 	  # There maybe a bug where an array is returned, even if categories are enabled
# 	  if(articles[:results].is_a?(Array))
# 		articles[:results] = {translate_phrase("most_recent", language) => most_recent_articles}
# 		articles['categories'] = []
# 	  else
# 		  articles[:results][translate_phrase("most_recent", language)] = most_recent_articles
# 		end
		
# 		articles["categories"].insert(0, translate_phrase("most_recent", language))
# 	  end
	  
# 	  articles
#   end
  
#   logger.debug("/articles.json #{params.to_s} Cache hit") if cache == true
#   logger.debug("/articles.json #{params.to_s} Cache missed") if cache == true

# 	return cached_articles
#   end

#   def self.article params
# 	language = language_parameter params['language']
# 	article_id = params['id']
# 	url = get_url "push-occrp=true&occrp_push_type=article&article_id=#{article_id}", language

# 	logger.debug("Fetching article id: article_id")

# 	return get_articles url
#   end

#   def self.search params
# 	  language = language_parameter params['language']

# 	  query = params['q']

# 	  google_search_engine_id = ENV['google_search_engine_id']
# 	  if(!google_search_engine_id.blank?)
# 		  logger.debug "Searching google with id: #{google_search_engine_id}"
# 		  articles_list = search_google_custom query, google_search_engine_id
# 		  url = get_url "push-occrp=true&occrp_push_type=urllookup&u=#{articles_list.join(',')}", language
# 	  else
# 		  url = get_url "push-occrp=true&occrp_push_type=search&q=#{query}", language
# 	  end

# 	  return get_articles url, {query: query}
#   end

#   def self.categories
# 	languages = languages();
# 	 languages = ['en'] if(languages.nil? || languages.count == 0)

	
#   categories = {}

# 	languages.each do |language|
# 	  # This is a temp for Kyiv Post, we need to fix the languages properly though...
# 	  response = Rails.cache.fetch("wordpress_categories_#{language}", expires_in: 1.day) do
# 			url = get_url "push-occrp=true&occrp_push_type=post_types", language
# 			logger.debug ("Fetching categories")
# 			make_request url
# 		end
		
# #  		byebug












