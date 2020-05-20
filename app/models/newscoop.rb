require "singleton"
require "resolv-replace"

class NewscoopSingleton
  @@lock = Mutex.new
  @@updated_at = nil
  @@expire_time = -1
  @@access_token = nil

  include Singleton

  attr_accessor :data

  def initialize
    @access_token = get_new_access_token
  end

  def access_token
    if check_for_expiration
      get_new_access_token
    else
      @access_token
    end
  end

  def get_new_access_token
    # We don't want the access token called over and over so we lock it
    # and inform other running process not to bother if it was updated in the last second.
    # this is probably overkill
    if !check_for_expiration
      return @access_token
    end

    @@lock.synchronize {
      client_id = ENV["newscoop_client_id"]
      client_secret = ENV["newscoop_client_secret"]
      url = ENV["newscoop_url"] + "/oauth/v2/token"

      options = { client_id: client_id,
              client_secret: client_secret,
              grant_type: "client_credentials" }

      response = HTTParty.get(url, query: options)

      response = JSON.parse(response.body)
      @@updated_at = Time.now.to_i
      @access_token = response["access_token"]
      @@expire_time = response["expires_in"]
    }
    @access_token
  end

  def add(key, value)
    @data[key] = value
  end

  def version
    "0.0.1"
  end

  # false mean valid, true mean invalid
  private

    def check_for_expiration
      current_time = Time.now
      # Build in a 10 second grace period
      expire_time_to_compare = @@expire_time - 10


      if @@expire_time > -1 &&
              @@updated_at != nil &&
              current_time.since(@@updated_at).to_i < expire_time_to_compare - 10
        return false
      end

      true
    end
end

class Newscoop < CMS
  def self.articles(params = {})
    access_token = Newscoop.get_auth_token
    url = ENV["newscoop_url"] + "/api/articles.json"
    language = params["language"]
    language = default_language() if language.nil?
    version = params["v"]

    options = { access_token: access_token, language: language, "sort[published]" => "desc" }

    logger.debug("Fetching articles")

    if !params["categories"].blank? && params["categories"]=="true"

      # Get all categories
      categories = self.categories(true)

      if !Setting.consolidated_categories
        options[:categorized]="true"
      end
    end


    cached = true
    items = {}

    if !categories.nil?

      @response = Rails.cache.fetch("categories_string/#{language}", expires_in: 1.hour) do
        # Pull set categories, and only fetch those
        begin
          categories_to_include = YAML.load(Setting.categories)
        rescue
          categories_to_include = {}
        end

        categories_to_include = {} unless categories_to_include.class == ActionController::Parameters


        if !Setting.show_most_recent_articles.nil?
          items[translate_phrase("most_recent", language).to_sym] = most_recent_articles(params)
        end

        categories[language].each do |category|
          if !categories_to_include.nil? && categories_to_include.include?(language) && !categories_to_include[language].include?(category["title"])
            next
          end

          response = Rails.cache.fetch("sections/#{category['title']}/#{language}/#{version}", expires_in: 1.hour) do
            url = ENV["newscoop_url"] + "/api/sections/#{category['number']}/#{language}/articles.json"

            logger.info("articles are not cached, making call to newscoop server")
            logger.debug "************************"
            logger.debug("calling url: #{url}")
            logger.debug "************************"
            cached = false
            response = HTTParty.get(url, query: options)
            # body = JSON.parse response.body
          end
          items[category["title"]] = format_newscoop_articles(response["items"])
        end
        response = format_newscoop_response(items, true)
        response["categories"] = items.keys
        # here we need to make a new format_newscoop_response to handle categories
        response
      end
    else
      @response = Rails.cache.fetch(params.flatten, expires_in: 1.hour) do
        cached = false
        format_newscoop_response(most_recent_articles(params), true)
      end
    end

    if cached == true
      logger.info("Cached hit for articles")
    else
      logger.info("Cached missed")
    end

    @response
  end

  def self.most_recent_articles(params = {})
    access_token = Newscoop.get_auth_token
    url = ENV["newscoop_url"] + "/api/articles.json"
    language = params["language"]
    version = params["v"]

    if language.blank?
      # Should be extracted
      language = "az"
    end

    options = { access_token: access_token, language: language, "sort[published]" => "desc" }

    response = Rails.cache.fetch("sections/#{language}/#{version}", expires_in: 1.hour) do
      logger.info("articles are not cached, making call to newscoop server")
      # cached = false
      response = HTTParty.get(url, query: options)
      body = JSON.parse response.body
      format_newscoop_articles(body["items"])
    end
    response
  end

  def self.search(params = {})
    query = params["q"]

    access_token = Newscoop.get_auth_token
    url = ENV["newscoop_url"] + "/api/search/articles.json"
    language = params["language"]
    if language.blank?
      language = "az"
    end

    options = { access_token: access_token, language: language, query: query }
    response = HTTParty.get(url, query: options)
    body = JSON.parse response.body

    body[:items] = body["items"]
    @response = format_newscoop_response(body)
  end

  def self.article(params = {})
    article_id = params["id"]

    access_token = Newscoop.get_auth_token
    url = ENV["newscoop_url"] + "/api/articles/#{article_id}.json"

    logger.debug("Calling newscoop url: ${url}")

    language = params["language"]
    # version = params["v"]

    if language.blank?
      # Should be extracted
      language = "az"
    end

    options = { access_token: access_token, language: language, "sort[published]" => "desc" }

    logger.info("Fetching article with id #{article_id}")

    # cached = true
    # @response = Rails.cache.fetch("newscoop_articles/#{article_id}/#{language}/#{version}", expires_in: 1.hour) do
    logger.info("article is not cached, making call to newscoop server")
    cached = false
    response = HTTParty.get(url, query: options)
    body = JSON.parse response.body
    @response = format_newscoop_response({ items: [body] })
    # end

    if cached == true
      logger.info("Cached hit for articles")
    else
      logger.info("Cached missed")
    end

    @response
  end

  def self.categories(full_objects = false, languages = nil)
    cached = true

    if languages.nil?
      languages = languages()
    elsif !languages().include? languages
      raise("attempting to access language not set")
    end

    @response = Rails.cache.fetch("sections/#{languages.join(',')}", expires_in: 1.hour) do
      categories = {}

      items = {}
      languages.each do |language|
        categories[language] = []

        if !Setting.show_most_recent_articles.nil?
          categories[language] << translate_phrase("most_recent", language)
        end


        items[language] = []
        url = ENV["newscoop_url"] + "/api/sections.json?language=#{language}"
        access_token = Newscoop.get_auth_token

        options = { access_token: access_token }

        logger.info("sections is not cached, making call to newscoop server")
        cached = false

        while true
          response = HTTParty.get(url, query: options)
          body = JSON.parse response.body
          begin
            items[language] = items[language] + body["items"]
          rescue Exception
            items[language] = body["items"]
          end

          if !body["pagination"]["nextPageLink"].nil? && !body["pagination"]["nextPageLink"].empty?
            url = body["pagination"]["nextPageLink"]
            options = ""
          else
            break
          end
        end
      end

      done = false
      to_return = items if full_objects == true
      done = true if !to_return.nil?

      if done == false
        items.keys.each do |language_items|
          items[language_items].each do |item|
            categories[language_items] << item["title"]
          end
        end
        to_return = categories
      end

      to_return
    end


    if cached == true
      logger.info("Cached hit for sections")
    else
      logger.info("Cached missed")
    end

    @response
  end

  def self.topics
    cached = true
    @response = Rails.cache.fetch("topics", expires_in: 1.hour) do
      url = ENV["newscoop_url"] + "/api/topics.json"
      access_token = Newscoop.get_auth_token

      options = { access_token: access_token }

      logger.info("sections is not cached, making call to newscoop server")
      cached = false

      items = []
      while true
        response = HTTParty.get(url, query: options)

        body = JSON.parse response.body

        items = items + body["items"]
        if !body["pagination"]["nextPageLink"].nil? && !body["pagination"]["nextPageLink"].empty?
          url = body["pagination"]["nextPageLink"]
          options = ""
        else
          break
        end
      end

      categories = []
      items.each do |item|
        categories << item["title"]
      end

      categories
    end


    if cached == true
      logger.info("Cached hit for sections")
    else
      logger.info("Cached missed")
    end

    @response
  end

  def self.get_auth_token
    NewscoopSingleton.instance.access_token
  end

  private

    def self.format_newscoop_response(body, preformatted = false)
      logger.debug("Received #{body}")
      response = {}
      response["start_date"] = nil
      response["end_date"] = nil
      response["page"] = 1

      if preformatted == false
        if (!body[:items].nil? && body[:items].class == Hash) || (!body["items"].nil? && body["items"].class == Hash)
          formatted_items = {}
          count = 0
          categories = []
          body[:items].keys.each do |key|
            category_title = key
            categories << category_title
            articles = body[:items][key]
            formatted_items[category_title] = format_newscoop_articles(articles)
            count += articles.count
          end
          response["total_items"] = count
          response["results"] = formatted_items
          response["categories"] = categories
        else
          response["total_items"] = body[:items].count
          response["results"] = format_newscoop_articles(body[:items])
        end
      else
        response["results"] = body
        if body.class == Hash
          response["total_items"] = body.keys.map { |key| body[key] }.flatten.count
        elsif body.class == Array
          response["total_items"] = body.count
        end
      end

      response
    end

    def self.format_newscoop_articles(articles)
      formatted_articles = []

      articles = [] if articles.nil?

      articles.each do |article|
        formatted_article = {}
        formatted_article["headline"] = article["title"]
        formatted_article["description"] = format_description_text article["fields"]["deck"]
        formatted_article["description"] = format_description_text article["fields"]["full_text"] if formatted_article["description"].blank?
        formatted_article["body"] = article["fields"]["full_text"]
        # formatted_article['body'] = scrubImageTagsFromHTMLString formatted_article['body']
        formatted_article["body"] = CMS.normalizeSpacing formatted_article["body"]

        if article["authors"] && article["authors"].count > 0
          formatted_article["author"] = article["authors"][0]["name"]
        end

        formatted_article["publish_date"] = article["published"].to_time.to_formatted_s(:number_date)
        # yes, they really call the id 'number'
        formatted_article["id"] = article["number"]
        formatted_article["language"] = article["languageData"]["RFC3066bis"]

        videos = []

        if !article["fields"]["youtube_shortcode"].blank?
          youtube_shortcode = article["fields"]["youtube_shortcode"]
          youtube_id = extractYouTubeIDFromShortcode(youtube_shortcode)

          videos << { youtube_id: youtube_id }
        end

        formatted_article["video"] = videos

        images = []

        if article["renditions"].count > 0 && !article["renditions"][0]["details"]["original"].blank?
          preview_image_url = "https://" + CGI.unescape(article["renditions"][0]["details"]["original"]["src"])
          passthrough_image_url = rewrite_image_url_for_proxy preview_image_url
          caption = article["renditions"][0]["details"]["caption"]
          width = article["renditions"][0]["details"]["original"]["width"]
          height = article["renditions"][0]["details"]["original"]["height"]
          byline = article["renditions"][0]["details"]["photographer"]
          # For backwards capabilities, we keep it in the main feed as well. This will be deprecated in later versions
          # the app will take care of removing it at the moment
          # image = { url: preview_image_url, caption: caption, width: width, height: height, byline: byline }
          image = { url: passthrough_image_url, caption: caption, width: width, height: height, byline: byline }
          images << image
          formatted_article["header_image"] = image
        end

        formatted_article["images"] = images

        article["url"] = "" if article["url"].nil?

        formatted_article["url"] = article["url"]
        formatted_article["author"] = article["author"].nil? ? "" : article["author"]

        formatted_articles << formatted_article
      end

      # cleaned_up_articles = clean_up_response(formatted_articles)
      cleaned_up_articles = formatted_articles.map { |article|
        article["body"] = normalizeSpacing(article["body"])
        article
      }

      cleaned_up_articles
    end


    def self.format_description_text(text)
      text = ActionView::Base.full_sanitizer.sanitize(text)

      if !text.nil?
        text.squish!

        if text.length > 140
          text = text.slice(0, 140) + "..."
        end
      else
        text = "..."
      end

      text
    end
end
