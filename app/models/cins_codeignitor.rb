class CinsCodeignitor < CMS

	def self.articles params
	    url = get_url '/api/articles'
	    language = params['language']
	    if(language.blank?)
	      # Should be extracted
	      language = "rs"
	    end

	    version = params["v"]

	    @response = Rails.cache.fetch("cins_codeigniter_articles/#{language}/#{version}", expires_in: 1.hour) do
	      logger.info("articles are not cached, making call to newscoop server")
	      response = HTTParty.get(url)
	      body = JSON.parse response.body
	      return_response = format_cins_codeignitor_response(body)
	      return_response['results'] = clean_up_response(return_response['results'])
	      logger.debug(return_response)
	      return return_response
	    end        
	end

	def self.article params
	    url = get_url '/api/article'
	    language = params['language']
	    if(language.blank?)
	      # Should be extracted
	      language = "rs"
	    end
	    
	    version = params["v"]
	    article_id = params['id']

	    @response = Rails.cache.fetch("cins_codeigniter_article/#{article_id}/#{language}/#{version}", expires_in: 1.hour) do
	      options = {id: params['id']}
	      logger.info("articles are not cached, making call to newscoop server")
	      response = HTTParty.get(url, query: options)
	      body = JSON.parse response.body
	      return format_cins_codeignitor_response(body)
	    end        
	end

	def self.search params
		url = get_url '/api/search'
	    language = params['language']
	    if(language.blank?)
	      # Should be extracted
	      language = "rs"
	    end

	    version = params["v"]

	    options = {q: params['q']}
	    response = HTTParty.get(url, query: options)
	    body = JSON.parse response.body
	    return format_cins_codeignitor_response(body)
	end






	private

	def self.get_url path
	    url = ENV['cins_codeignitor_url'] 
	    return "#{url}#{path}"
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

	def self.format_cins_codeignitor_response body
		items = body['results']
		new_items = []
		items.each do |item|
  		item['body'] = "<strong>" + item['description'] + "</strong>" + "<br><br>" + item['body']
		  logger.debug "Parsing: #{item['publish_date']}"
		  date = Date.strptime(item['publish_date'], "%Y-%m-%d %H:%M:%S")
		  item['publish_date'] = date.strftime("%Y%m%d")

		  extract_images item

		  # There's a bug in the cins plugin that doesn't add protocols to links
		  # This should fix it
		  # first determine if it's a link to CINS
		  # If it is, then add https

		  url = Addressable::URI.parse(base_url)

		  elements = Nokogiri::HTML::fragment item['body']
		  elements.css('a').each do |link|
		    uri = Addressable::URI.parse(link.attribute("href"))
		    url_host = url.host.gsub("www.", "")
		    uri_host = uri.host.gsub("www.", "")
		    if(url_host == uri_host)
		      uri.scheme = 'https'
		      link.attribute("href").value = uri.to_s
		    end
		  end

		  elements.css('p').each do |tag|
		  	if tag.content.squish.blank?
		  		tag.remove
		  	end
		  end

		  item['body'] = elements.to_html
		  item['body'] = add_formatting_for_sidebars item['body']
		  new_items.push item


		end

		body['results'] = new_items
		return body
	end

	def self.add_formatting_for_sidebars html
		elements = Nokogiri::HTML::fragment html
		elements.css('div.enterfile').each do |sidebar|
			style = sidebar['style']
			if(style == nil)
				style = ""
			else
				style += ";"
			end

	        #style += "background-color: #e6e6e6; color: #3a3a3a"
	        style += "color: #3a3a3a"
	        sidebar['style'] = style
	        
	        sidebar.prepend_child("<br />—<br />")
	        sidebar.add_child("<br />—<br />")
	        
	    end

		return elements.to_html
	end

end