class Wordpress < CMS

	def self.articles params
    	language = language_parameter params['language']
	    url = get_url "push-occrp=true&type=articles", language
	    return get_articles url
	end

	def self.article params
	  language = language_parameter params['language']
      article_id = params['id']
      url = get_url "push-occrp=true&type=article&article_id=#{article_id}", language

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
			url = get_url "push-occrp=true&type=urllookup&u=#{articles_list.join(',')}", language
		else
		    url = get_url "push-occrp=true&type=search&q=#{query}", language
		end

		return get_articles url, {query: query}
	end






	private

	def self.get_url path, language
	    url = ENV['wordpress_url'] 
	    return "#{url}#{language}?#{path}"
	end

	def self.get_articles url, extras = {},  version = 1

	    logger.debug("Calling: #{url}")

		response = HTTParty.get(url)
	    body = JSON.parse response.body

	    if(body['results'].nil?)
	    	body['results'] = Array.new
	    end

	    results = clean_up_response(body['results'], version)
	    results = clean_up_for_wordpress results

	    response = {start_date: "19700101",
	               end_date: DateTime.now.strftime("%Y%m%d"),
	               total_results: results.size,
	               page: "1",
	               results: results
	              }

	    # add in any extras from the call, query string etc.
	    response = response.merge(extras)
	    return response
	end

	def self.language_parameter language
	    if(!language.blank?)
	      language = "/#{language}/"
	    end

	    return language
	end

	def self.clean_up_for_wordpress articles	
		articles.each do |article|
		    article['body'] = scrubWordpressTagsFromHTMLString article['body']
		    article['body'] = cleanUpNewLines article['body']
		    article['body'] = scrubScriptTagsFromHTMLString article['body']
		    article['body'] = scrubJSCommentsFromHTMLString article['body']
		    article['body'] = scrubSpecialCharactersFromSingleLinesInHTMLString article['body']
		    article['body'] = scrubHTMLSpecialCharactersInHTMLString article['body']
		    article['headline'] = HTMLEntities.new.decode(article['headline'])
		end

	    return articles
	end


end