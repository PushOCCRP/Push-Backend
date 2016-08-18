class Wordpress < CMS

	def self.articles params

    	language = language_parameter params['language']
    	options = {}

    	categories_string = Setting.categories
    	if(!categories_string.blank?)
    		logger.debug("categories not blank")
    		categories = categories_string.split('::')
    		options[:post_types] = categories.join(',')
    	end

	    url = get_url "push-occrp=true&occrp_push_type=articles", language, options
	    return get_articles url
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
	    response = Rails.cache.fetch("wordpress_categories", expires_in: 1.day) do
			url = get_url "push-occrp=true&occrp_push_type=post_types", nil
			logger.debug ("Fetching categories")
			make_request url
		end

		if(response.count == 0)
			response = {post: 'post'}
		end

		return response.keys
	end



	private

	def self.get_url path, language, options = {}
	    url = ENV['wordpress_url'] 
	    url_string = "#{url}#{language}?#{path}"
	    
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
		response = HTTParty.get(url)
	    body = JSON.parse response.body

	    return body
	end

	def self.get_articles url, extras = {},  version = 1

	    logger.debug("Calling: #{url}")

	    body = make_request url

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
		    article['body'] = scrubCDataTags article['body']
   		    article['body'] = scrubScriptTagsFromHTMLString article['body']
		    article['body'] = scrubWordpressTagsFromHTMLString article['body']
		    #article['body'] = cleanUpNewLines article['body']
		    article['body'] = scrubJSCommentsFromHTMLString article['body']
   		    article['body'] = normalizeSpacing article['body']
		    article['body'] = scrubSpecialCharactersFromSingleLinesInHTMLString article['body']
		    article['body'] = scrubHTMLSpecialCharactersInHTMLString article['body']
		    article['headline'] = HTMLEntities.new.decode(article['headline'])
		end

	    return articles
	end

	def self.normalizeSpacing text
		gravestone = "mv9da0K3fP"

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

		text.gsub!('<p>', '')
		text.gsub!('</p>', '')

		text.gsub!(/[\s]*(mv9da0K3fP)+[\s]*/, '<br /><br />')


		# NOTE: some <p> tags may stay in, especially if there's formatting inlined on it.
		# This removes one of the <br />s before it
		# We can also assume they're using <p> tags, so, we should add closers, since they were removed
		text.gsub!(/([\s]*<br \/>[\s]*)+<p/, '</p><br /><p')
		
		return text
	end

	def self.removeHorizontalRules text
		elements = Nokogiri::HTML::fragment text
	    elements.css('hr').each do |node|
	      node.remove
	    end
	    return elements.to_html
	end




























end