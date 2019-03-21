class SnWorksCeo < CMS

  # Don't forget to add caching!
	def self.articles params
  	language = 'en'
	  url = get_url "/v3/content", language
	  articles = get_articles url
  
	  return articles
	end

	def self.article params
	  language = language_parameter params['language']
      article_id = params['id']
      url = get_url "push-occrp=true&occrp_push_type=article&article_id=#{article_id}", language

      logger.debug("Fetching article id: article_id")

      return get_articles url
	end

	def self.search params
		language = language_parameter params['language']

	    query = params['q']

	    google_search_engine_id = ENV['google_search_engine_id']
		if(!google_search_engine_id.blank?)
			logger.debug "Searching google with id: #{google_search_engine_id}"
			articles_list = search_google_custom query, google_search_engine_id
			url = get_url "push-occrp=true&occrp_push_type=urllookup&u=#{articles_list.join(',')}", language
		else
		    url = get_url "push-occrp=true&occrp_push_type=search&q=#{query}", language
		end

		return get_articles url, {query: query}
	end

	def self.categories
  	languages = languages();
   	languages = ['en'] if(languages.nil? || languages.count == 0)

  	
    categories = {}

  	languages.each do |language|
    	# This is a temp for Kyiv Post, we need to fix the languages properly though...
  	  response = Rails.cache.fetch("wordpress_categories_#{language}", expires_in: 1.day) do
  			url = get_url "push-occrp=true&occrp_push_type=post_types", language
  			logger.debug ("Fetching categories")
  			make_request url
  		end
  		  		
	    if(response.class == Hash)
        categories[language] = response.keys
      else
   	    categories[language] = response
   	  end
      
      categories[language] = ['post'] if(response.count == 0)
    end
   	
 		return categories
	end

#  	private

  def self.headers_for_request
    { 
      "Content-Type":  "application/json",
      "Authorization": "Bearer #{self.bearer_token}"
    }
  end

  def self.bearer_token
  	payload = { pk: Figaro.env.snworks_public_api_key,
                iss: "https://www.dailycardinal.com",
                aud: "https://www.dailycardinal.com",
                iat: (DateTime.now).strftime("%F %T"),
                exp: (DateTime.now + 5.minutes).strftime("%F %T")
  	          }
    byebug
    # IMPORTANT: set nil as password parameter
    token = JWT.encode payload, Figaro.env.snworks_private_api_key, "HS256"
    token
  end

	def self.get_url path, language, options = {}
	    url = ENV['snworks_url'] 
 	    url_string = "#{url}?#{path}"
	    url_string
	end

	def self.make_request url
		# logger.debug("Making request to #{url}")
		header = { 
  		         'Content-Type': 'application/json',
  		         'Authorization': "Bearer #{self.bearer_token}"
		         }
		options = { headers: header }
		byebug
  	response = HTTParty.get(URI.encode_www_form(url), options)    
    begin
	    body = JSON.parse response.body
	  rescue => exception
#       logger.debug "Exception parsing JSON from CMS"
#       logger.debug "Statement returned"
#       logger.debug "---------------------------------------"
#       logger.debug response.body
#       logger.debug "---------------------------------------"
      raise
    end
	  return body
	end

	def self.get_articles url, extras = {},  version = 1

	    # logger.debug("Calling: #{url}")

	    body = make_request url
      #byebug
# 	    if(body['results'].nil?)
# 	    	body['results'] = Array.new
# 	    end
#       
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
# 
#     	    results[category] = clean_up_response(body['results'][category], version)
#     	    results[category] = clean_up_for_wordpress results[category]
#     	  end    	  
#   	  end
# 
# 	    response = {start_date: "19700101",
#   	              end_date: DateTime.now.strftime("%Y%m%d"),
#   	              total_results: results.size,
#   	              page: "1",
#   	              results: results
#   	             }
# 	   
# 	    response['categories'] = body['categories'] if !body['categories'].nil?
# 
# 	    # add in any extras from the call, query string etc.
# 	    response = response.merge(extras)
# 	    return response
      body
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
		end

	  articles
	end
end