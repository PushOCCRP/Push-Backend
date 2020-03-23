class SnWorksCeo < CMS

  # Trying something new and better here to use structs instead of weird
  # json hashes everywhere
  Article = Struct.new(:id, :headline, :body, :description, :publish_date, :header_image,
                       :images, :image_urls, :videos, :captions, :author) do
    def to_json a = nil
      hash = self.to_h
      hash[:publish_date] = self.publish_date.strftime("%Y%j")
      return hash.to_json
    end
  end
  
  Image = Struct.new(:url, :caption, :byline, :width, :height, :length, :start) do
    def to_json a = nil
      return self.to_h.to_json
    end
  end
  

  # Don't forget to add caching!
	def self.articles params
  	language = 'en'
	  url = get_url "/v3/content", language
	  articles = get_articles url
  
	  return { start_date: 19700101,
  	           end_date: 201901001,
  	           total_results: articles.count,
  	           total_pages: 1,
  	           page: 0, 
  	           results: articles
  	         }
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

 # 	private

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
    # IMPORTANT: set nil as password parameter
    token = JWT.encode payload, Figaro.env.snworks_private_api_key, "HS256"
    token
  end

	def self.get_url path, language, options = {}
	    url = ENV['snworks_url']
 	    url_string = "#{url}#{path}"
	    url_string
	end

	def self.make_request url
		# logger.debug("Making request to #{url}")
		header = { 
  		         'Content-Type': 'application/json',
  		         'Authorization': "Bearer #{self.bearer_token}"
		         }
		options = { headers: header }
    	response = HTTParty.get(url, options)
    	
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
	    body = make_request url
      #byebug
 	    	body['items'] = Array.new if body['items'].nil?
	    
	    articles = []
	    
	    body['items'].each do |item|
  	      
  	      # Let's ignore it if there's no publish date (since it hasn't been published)
  	      next if item['published_at'].blank?
  	      
  	      # There are a few different types from SNNews
  	      # 'article' and 'media' are what I'm aware of now
  	      # We really only want 'article' for the moment
  	      
  	      if item['type'] == 'article'
          articles << article_from_json_response(item)
        end
  	    end
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
      articles
	end
	
	def self.get_article uuid
  	  url = self.url_for_article_uuid uuid
  	  article_json = self.make_request url
  	  
  	  article_json
  	end
  	
  	def self.url_for_article_uuid uuid
    	"#{self.get_url '', 'en'}/v3/content/#{uuid}"
  end
	
	# SnWorksCEO, like a lot of news cms's (for reasons I will never fucking understand)
	# doesn't provide full content when lising articles.
	# So now, we have to loop through and make individual requests. SOB....
	def self.article_from_json_response json
  	  json = self.get_article(json['uuid']).first
  	
  	  article = Article.new
  	  article.id = json['id']
  	  article.headline = json['title']
  	  article.description = ActionView::Base.full_sanitizer.sanitize(json['abstract'])
  	  article.body = json['content']
  	  article.publish_date = DateTime.parse(json['published_at'])
  	  article.author = json["authors"].map{|a| a['name']}.join(', ')
  	  article.images = []
  	  article.captions = []
  	  article.videos = []
  	  
  	  unless json['dominantAttachment'].blank?
    	  image = self.image_from_json_response json['dominantAttachment']
    	  article.header_image = image
    else
      article.header_image = {}
    end
    
  	  article
  end
  
  def self.image_from_json_response json
    # Turns out the content call is the same for images and articles
    image_json = self.get_article json['uuid'].first

    image = Image.new
    
    image.url = json['attachment']['public_url']
    image.caption = ActionView::Base.full_sanitizer.sanitize(json['content'])

    #image.byline = json['authors'].map{|a| a['name']}.join(', ') unless json['authors'].blank?

    image.byline = json['authors'].nil? ? "" : json['authors'].first['name']
    image.height = json['attachment']['height']
    image.width = json['attachment']['width']
    
    image.length = 0
    image.start = 0
    
    image
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