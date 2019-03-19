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
			
			if language == 'ru'
				articles['categoriesOrder'] = { "НОВОСТИ" => "1", "ГЛАВНАЯ" => "2", "РАССЛЕДОВАНИЯ" => "3" } 
			  
			 else
				articles['categoriesOrder'] = { "Home" => "1", "Daily" => "2", "Investigations" => "3" } 
      end





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