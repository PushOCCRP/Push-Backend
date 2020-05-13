class SNWorksCEO < CMS
  # Trying something new and better here to use structs instead of weird
  # json hashes everywhere
  Article = Struct.new(:id, :headline, :body, :description, :publish_date, :header_image,
   :images, :image_urls, :videos, :captions, :author, :url) do
    def to_json(a = nil)
      hash = self.to_h
      hash[:publish_date] = self.publish_date.strftime("%Y%m%d")
      hash[:description]  = CMS.format_description_text self.body[0..140]
      hash.to_json
    end
  end

  Image = Struct.new(:url, :caption, :byline, :width, :height, :length, :start) do
    def to_json(a = nil)
      self.to_h.to_json
    end
  end

  # Don't forget to add caching!
  def self.articles(params = {})
    url = get_url "/v3/content"
    Rails.cache.fetch(url, expires_in: 5.minutes) do
      articles = get_articles url

      # Insure that the top article always has an image.
      articles = rearrange_articles_for_images articles

      { start_date: 19700101,
        end_date: 201901001,
        total_results: articles.count,
        total_pages: 1,
        page: 0,
        results: articles
      }
    end
  end

  def self.article(params = {})
    id = params["id"]
    Rails.cache.fetch("single_article/#{id}", expires_in: 5.minutes) do
      article_json = article_from_uuid id

      { start_date: 19700101,
        end_date: 201901001,
        total_results: 1,
        total_pages: 1,
        page: 0,
        results: [article_json]
      }
    end
  end

  def self.search(params = {})
    query = params["q"]

    url = get_url "/v3/search", { type: "content", keywords: query }

    Rails.cache.fetch("/v3/search/#{query}", expires_in: 5.minutes) do
      articles = get_articles url, { query: query }

      { start_date: 19700101,
        end_date: 201901001,
        total_results: articles.count,
        total_pages: 1,
        page: 0,
        results: articles
      }
    end
  end


  #   private

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
     iat: (DateTime.now).to_i, # .strftime("%F %T"),
     exp: (DateTime.now + 5.minutes).to_i # .strftime("%F %T")
   }
    # IMPORTANT: set nil as password parameter
    logger.debug "payload #{payload.inspect}"
    token = JWT.encode payload, Figaro.env.snworks_private_api_key, "HS256"
    token
  end

  def self.get_url(path, options = {})
    url = ENV["snworks_url"]
    url_string = "#{url}#{path}"

    unless options.blank?
      url_string += "?"
      options_array = options.map { |(key, value)| "#{key}=#{value}" }
      url_string += options_array.join "&"
    end

    url_string
  end

  # Note that in SEO Works `url` should always be https://car.ceo.getsnworks.com
  def self.make_request(url)
    # logger.debug("Making request to #{url}")
    header = {
      'Content-Type': "application/json",
      'Authorization': "Bearer #{self.bearer_token}"
    }

    puts "Getting url: #{url}"
    options = { headers: header }
    puts "Options: #{options}"

    response = HTTParty.get(url, options)

    begin
      body = JSON.parse response.body
    rescue Exception => e
      logger.debug "Exception parsing JSON from CMS"
      logger.debug "Statement returned"
      logger.debug "---------------------------------------"
      logger.debug response.body
      logger.debug "---------------------------------------"
      raise e
    end

    body
  end

  def self.get_articles(url, extras = {},  version = 1)
    body = make_request url
    # byebug
    body["items"] = Array.new if body["items"].nil?

    articles = []

    body["items"].each do |item|
        # Let's ignore it if there's no publish date (since it hasn't been published)
        next if item["published_at"].blank?

        # There are a few different types from SNNews
        # 'article' and 'media' are what I'm aware of now
        # We really only want 'article' for the moment

        if item["type"] == "article"
          article = article_from_json_response(item)
          articles << article
        end
      end

    articles
  end

  def self.get_article(uuid)
    url = self.url_for_article_uuid uuid
    article_json = self.make_request url

    article_json
  end

  def self.url_for_article_uuid(uuid)
    "#{self.get_url ''}/v3/content/#{uuid}"
  end

  # SnWorksCEO, like a lot of news cms's (for reasons I will never fucking understand)
  # doesn't provide full content when lising articles.
  # So now, we have to loop through and make individual requests. SOB....
  def self.article_from_json_response(json)
    article_from_uuid(json["uuid"])
  end

  def self.article_from_uuid(uuid)
    article_json = self.get_article(uuid).first

    article = Article.new
    article.id = article_json["uuid"]
    article.headline = article_json["title"]
    article.description = ActionView::Base.full_sanitizer.sanitize(article_json["abstract"])
    article.body = article_json["content"]
    article.publish_date = DateTime.parse(article_json["published_at"])
    article.author = article_json["authors"].map { |a| a["name"] }.join(", ")
    article.images = []
    article.captions = []
    article.videos = []

    # This is a standin until I hear back from SNWorks, since this is REALLY smelly code
    article.url = "#{ENV["host_url"]}/article/#{article.publish_date.year}/#{format('%02d', article.publish_date.month)}/#{article_json["slug"]}"

    unless article_json["dominantAttachment"].blank?
      image = self.image_from_json_response article_json["dominantAttachment"]
      article.header_image = image
    else
      article.header_image = {}
    end

    article
  end

  # Return an `Image` OpenStruct object for a `json` response from a call to the SEOWorks API
  def self.image_from_json_response(json)
    image = Image.new

    image.url = json["attachment"]["public_url"]
    image.caption = ActionView::Base.full_sanitizer.sanitize(json["content"])
    image.byline = json["authors"].nil? ? "" : json["authors"].first["name"]
    image.height = json["attachment"]["height"]
    image.width = json["attachment"]["width"]

    # There's a weird bug in SEOWorks where images which have valid URLs sometimes have dimensions
    # set to null. This uses ImageMagick to download the images and then check their dimensions
    # ourselved.
    #
    # This is a SUPER heavy way to do it, and requires us to install ImageMagick and the Rmagick
    # gem. Which is not good. I've reached out to SEOWorks and we'll see if they will fix this
    # bug on their side.
    #
    # If there's no image found at the `public_url` we'll just return an empty obejct, because
    # otherwise it crashes the app, which is bad.
    if image.height.nil?
      logger.debug ">>> Image dimensions are nil, getting them from ImageMagick"
      dimensions = get_image_dimensions json["attachment"]["public_url"]
      # Return an empty object if we can't find a valid URL
      return {} if dimensions.nil?

      # Set the image dimensions we get from ImageMagick
      image.height = dimensions[:height]
      image.width = dimensions[:width]
    end

    image.length = 0
    image.start = 0

    image
  end

  # Download the the image at `url`, returning nil if there's not a response or it's blank.
  # Otherwise, use ImageMagick to get the dimentions of the blob that's downloaded.
  #
  # Note: We'd like to get rid of this ASAP if SEOWorks can fix the bug on their backend where
  # dimensions are returns as null from the API request.
  def self.get_image_dimensions(url)
    # Download URL to blob, return nil if it doesn't work
    response = HTTParty.get(url, follow_redirects: true)
    return nil if response.code != 200 || response.body.blank?

    # Image is created from the response body
    begin
      img = Magick::Image.from_blob(response.body).first
    rescue StandardErorr
      # If there's an error with the image, for instance if the url doesn't point to an image,
      # we just want to return nothing, it'll be a problem on SEOWork's side
      return {}
    end

    { height: img.rows, width: img.columns }
  end

  def self.clean_up_for_wordpress(articles)
    articles.each do |article|
       article["body"] = scrubCDataTags article["body"]
       article["body"] = scrubScriptTagsFromHTMLString article["body"]
       article["body"] = scrubWordpressTagsFromHTMLString article["body"]
       # article['body'] = cleanUpNewLines article['body']
       article["body"] = scrubJSCommentsFromHTMLString article["body"]
       article["body"] = scrubSpecialCharactersFromSingleLinesInHTMLString article["body"]
       article["body"] = scrubHTMLSpecialCharactersInHTMLString article["body"]
       article["body"] = normalizeSpacing article["body"]

       article["headline"] = HTMLEntities.new.decode(article["headline"])
     end

    articles
  end
end
