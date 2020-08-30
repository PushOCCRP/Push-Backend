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

  # SNWorks uses tags to indicate categories. This pulls them all.
  # Note: we don't cache this since it can change pretty often and isn't used by the apps.
  def self.categories(params = {})
    categories = Setting["snworks_categories"]
    categories
  end

private

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

    # Make sure we have a real article at the top, not a paid advertisement
    articles = rearrange_articles_for_native_advertising articles

    articles
  end

  # The original organization that this integration was created for does paid native advertising.
  # The only way to determine which is paid however is to look at the author, which in the original
  # case is 'Scholarship Media'. This will rearrange the articles so that the paid ad is never at
  # the top.
  def self.rearrange_articles_for_native_advertising(articles)
    paid_author_name = "Scholarship Media"
    # If the top article is not the designated author then just return
    return articles unless articles.first.author == paid_author_name

    # Go through the array until we find an article not authored by the name. Just in case there
    # are two or more in a row.
    first_real_article = nil
    first_real_article_index = nil
    articles.each_with_index do |article, index|
      # If the article's author is the paid one, just skip to the next element in the array
      next unless article.author != paid_author_name

      # Set the variables for later processing
      first_real_article = article
      first_real_article_index = index

      # We don't want to keep going, so we break
      break
    end

    # Just a quick rescue in case our logic is weird, shouldn't be odd.
    return articles if first_real_article.nil?

    # Remove the element we want to be at the front
    articles.delete_at first_real_article_index
    # Now insert the element to the front
    articles.unshift first_real_article
    articles
  end

  def self.get_content(uuid)
    url = self.url_for_content_uuid uuid
    article_json = self.make_request url

    article_json
  end

  def self.url_for_content_uuid(uuid)
    "#{self.get_url ''}/v3/content/#{uuid}"
  end

  # SnWorksCEO, like a lot of news CMS's (for reasons I will never fucking understand)
  # doesn't provide full content when listing articles.
  # So now, we have to loop through and make individual requests. SOB....
  # Additional note: Same thing for stuff like images. It'll return the caption, but not the bylines.
  def self.article_from_json_response(json)
    article_from_uuid(json["uuid"])
  end

  def self.article_from_uuid(uuid)
    article_json = self.get_content(uuid).first

    article = Article.new
    article.id = article_json["uuid"]
    article.headline = article_json["title"]
    article.description = ActionView::Base.full_sanitizer.sanitize(article_json["abstract"])
    article.body = article_json["content"]
    article.publish_date = DateTime.parse(article_json["published_at"])
    article.author = article_json["authors"].map { |a| a["name"] }.join(", ")
    article.images = []
    article.image_urls = []
    article.captions = []
    article.videos = []

    # This is a stand in until I hear back from SNWorks, since this is REALLY smelly code
    # Update: this is the correct way to do it. Yes, it's janky.
    article.url = "#{ENV["host_url"]}/article/#{article.publish_date.year}/#{format('%02d', article.publish_date.month)}/#{article_json["slug"]}"

    unless article_json["dominantAttachment"].blank?
      image = self.image_from_uuid article_json["dominantAttachment"]["uuid"]
      article.header_image = image
    else
      article.header_image = {}
    end

    # This extracts all image tags and gets us a bunch of the info in them.
    article = self.extract_images(article)
    # Now that we've pulled all the images out, we need to get more information for them. Yep, this
    # is awful, but it's only available via *another* request :-)
    article.images = article.images.map { |i| image_from_uuid(i[:uuid]) }

    article
  end

  def self.image_from_uuid(uuid)
    json = self.get_content(uuid).first
    image = Image.new

    image.url = json["attachment"]["public_url"]
    image.caption = ActionView::Base.full_sanitizer.sanitize(json["content"])
    image.byline = json["authors"].map { |author| author["name"] }.join(", ")
    image.height = json["attachment"]["height"]
    image.width = json["attachment"]["width"]

    # There's a weird bug in SEOWorks where images which have valid URLs sometimes have dimensions
    # set to null. This uses ImageMagick to download the images and then check their dimensions
    # ourselves.
    #
    # This is a SUPER heavy way to do it, and requires us to install ImageMagick and the RMagick
    # gem. Which is not good. I've reached out to SEOWorks and we'll see if they will fix this
    # bug on their side.
    #
    # If there's no image found at the `public_url` we'll just return an empty object, because
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
  # Otherwise, use ImageMagick to get the dimensions of the blob that's downloaded.
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
end
