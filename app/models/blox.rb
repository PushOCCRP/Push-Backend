class Blox < CMS

	def self.articles params

	end

	def self.article params
	end

	def self.search params
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
		publications = get_publications
		
		valid_publication = nil
		publications.each{|publication| valid_publication = publication if publication['name'] == ENV['blox_publication_name']}
		raise "Publication in secrets.env not found" if valid_publication.nil?

		editions = get_editions valid_publication['id']
		raise "No editions found for publication_id #{valid_publication['id']}" unless editions.count > 0
		newest_edition = editions[0]
		publish_date = newest_edition['edition_date']

		pages = get_pages newest_edition['id']

		articles = []
		pages.each do |page|
			articles += parse_page(page,publish_date)
		end

		return articles
	end

	def self.get_publications
		cache = true;
    cached_publications = Rails.cache.fetch("publications", expires_in: 1.hour) do
      cache = false;
                  
	    url = get_url "/eedition/list_publications/"
	    
	    response = HTTParty.get(url, basic_auth: auth_credentials)
	    body = JSON.parse response.body

	    # Since the array returned is all of what we're looking for, we just return it.
	    return body
	  end
    
    logger.debug("get_publications #{params.to_s} Cache hit") if cache == true
    logger.debug("get_publications #{params.to_s} Cache missed") if cache == false
  
	  return cached_publications
	end

	def self.get_editions publication_id
		cache = true;
    cached_editions = Rails.cache.fetch("editions/#{publication_id}", expires_in: 1.hour) do
      cache = false;
            
	    url = get_url "/eedition/list_editions/?pub_id=#{publication_id}"
	    
	    response = HTTParty.get(url, basic_auth: auth_credentials)
	    body = JSON.parse response.body

	    # Since the array returned is all of what we're looking for, we just return it.
	    return body
	  end
    
    logger.debug("get_editions #{publication_id} Cache hit") if cache == true
    logger.debug("get_editions #{publication_id} Cache missed") if cache == false
  
	  return cached_editions
	end

	def self.get_pages edition_id
		cache = true;
    cached_pages = Rails.cache.fetch("list_pages/#{edition_id}", expires_in: 1.hour) do
      cache = false;
            
	    url = get_url "/eedition/list_pages/?edition_id=#{edition_id}"
	    
	    response = HTTParty.get(url, basic_auth: auth_credentials)
	    body = JSON.parse response.body

	    # Since the array returned is all of what we're looking for, we just return it.
	    return body['pages']
	  end
    
    logger.debug("get_pages #{edition_id} Cache hit") if cache == true
    logger.debug("get_pages #{edition_id} Cache missed") if cache == false
  
	  return cached_pages
	end

	def self.parse_page json, edition_date
		return unless json.has_key?('json_url')

		url = json['json_url']

		page = Rails.cache.fetch("page/#{url}", expires_in: 1.hour) do
      cache = false;
            	    
	    response = HTTParty.get(url, basic_auth: auth_credentials)
	    body = JSON.parse response.body

	    articles = []

	    segments = body['segments']
	    segments.each do |segment|
	    	asset = segment['asset']
	    	next unless asset['type'] == 'article'

	    	article = {}
	    	article['headline'] = asset['headline']
	    	article['description'] = asset['prologue']
	    	article['body'] = asset['content'].join(' ')
	    	article['publish_date'] = edition_date
	    	article['id'] = asset['id']
	    	article['url'] = asset['urls']['absolute']

	    	articles << article
	    end

	    # Since the array returned is all of what we're looking for, we just return it.
   		cleaned_articles = clean_up_response(articles)
	    return cleaned_articles
	  end
    
    logger.debug("page #{url} Cache hit") if cache == true
    logger.debug("page #{url} Cache missed") if cache == false

    return page
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

	def self.auth_credentials
		auth = {:username => ENV['blox_key'], :password => ENV['blox_secret']}
	end

end