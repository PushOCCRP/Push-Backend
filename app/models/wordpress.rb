class Wordpress < CMS
  def self.articles(params = {})
    cache = true
    cached_articles = Rails.cache.fetch("sections/#{params}", expires_in: 1.hour) do
      cache = false

      language = language_parameter params["language"]
      language = default_language if language.blank?
      raise "Requested language is not enabled"  if !languages().include?(language)

      options = {}
      # articles = {}

      categories_string = Setting.categories
      most_recent_articles = nil

      if !categories_string.blank? && !params["categories"].blank? && params["categories"]=="true" && Setting.consolidated_categories.blank?
        categories = YAML.load(categories_string)
        categories[language] = [] if categories[language].nil?
        options[:post_types] = categories[language].join(",")
        if !Setting.consolidated_categories
          options[:categorized]="true"
        end

        most_recent_articles_params = params.dup
        most_recent_articles_params["categories"] = nil

        most_recent_articles = articles(most_recent_articles_params)[:results]
      end

      url = get_url "push-occrp=true&occrp_push_type=articles", language, options

      articles = get_articles url
      if !most_recent_articles.nil? && !Setting.show_most_recent_articles.nil?
        # There maybe a bug where an array is returned, even if categories are enabled
        if articles[:results].is_a?(Array)
          articles[:results] = { translate_phrase("most_recent", language) => most_recent_articles }
          articles["categories"] = []
        else
          articles[:results][translate_phrase("most_recent", language)] = most_recent_articles
        end

        articles["categories"].insert(0, translate_phrase("most_recent", language))
      end

      articles
    end

    logger.debug("/articles.json #{params} Cache hit") if cache == true
    logger.debug("/articles.json #{params} Cache missed") if cache == false

    cached_articles
  end

  def self.article(params = {})
    language = language_parameter params["language"]
    article_id = params["id"]
    url = get_url "push-occrp=true&occrp_push_type=article&article_id=#{article_id}", language

    logger.debug("Fetching article id: article_id")

    get_articles url
  end

  def self.search(params = {})
    language = language_parameter params["language"]

    query = params["q"]

    google_search_engine_id = ENV["google_search_engine_id"]
    if !google_search_engine_id.blank?
      logger.debug "Searching google with id: #{google_search_engine_id}"
      articles_list = search_google_custom query, google_search_engine_id
      url = get_url "push-occrp=true&occrp_push_type=urllookup&u=#{articles_list.join(',')}", language
    else
      url = get_url "push-occrp=true&occrp_push_type=search&q=#{query}", language
    end

    get_articles url, { query: query }
  end

  def self.categories
    languages = languages()
    languages = ["en"] if languages.nil? || languages.count == 0


    categories = {}

    languages.each do |language|
      # This is a temp for Kyiv Post, we need to fix the languages properly though...
      response = Rails.cache.fetch("wordpress_categories_#{language}", expires_in: 1.day) do
        url = get_url "push-occrp=true&occrp_push_type=post_types", language
        logger.debug ("Fetching categories")
        make_request url
      end

      #      byebug

      if response.class == Hash
        categories[language] = response.keys
      else
        categories[language] = response
      end

      categories[language] = ["post"] if response.count == 0
    end

    categories
  end

  private

    def self.get_url(path, language, options = {})
      url = ENV["wordpress_url"]

      url_string = "#{url}?#{path}"

      # If there is more than one language specified (or any language at all for backwards compatibility)
      if languages().count > 1 && languages().include?(language)
        url_string = "#{url}/#{language}?#{path}"
      end

      if !ENV["wp_super_cached_donotcachepage"].blank?
        options[:donotcachepage] = ENV["wp_super_cached_donotcachepage"]
      end

      options.keys.each do |key|
        url_string += "&#{key}=#{options[key]}"
      end

      url_string
    end

    def self.make_request(url)
      logger.debug("Making request to #{url}")
      response = HTTParty.get(CGI.encode(url))

      begin
        body = JSON.parse response.body
      rescue
        logger.debug "Exception parsing JSON from CMS"
        logger.debug "Statement returned"
        logger.debug "---------------------------------------"
        logger.debug response.body
        logger.debug "---------------------------------------"
        raise
      end
      body
    end

    def self.get_articles(url, extras = {},  version = 1)
      logger.debug("Calling: #{url}")

      body = make_request url

      if body["results"].nil?
        body["results"] = Array.new
      end

      if body["categories"].nil?
        results = clean_up_response(body["results"], version)
        results = clean_up_for_wordpress results
      else
        results = {}
        body["categories"].each do |category|
          if body["results"][category].blank?
            results[category] = []
            next
          end

          results[category] = clean_up_response(body["results"][category], version)
          results[category] = clean_up_for_wordpress results[category]
        end
      end

      response = { start_date: "19700101",
                 end_date: DateTime.now.strftime("%Y%m%d"),
                 total_results: results.size,
                 page: "1",
                 results: results
                }

      response["categories"] = body["categories"] if !body["categories"].nil?

      # add in any extras from the call, query string etc.
      response = response.merge(extras)
      response
    end

    def self.language_parameter(language)
      if !language.blank?
        language = language
      end

      language
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
        article["body"] = handle_paragraph_tags article["body"]

        article["headline"] = HTMLEntities.new.decode(article["headline"])
      end

      articles
    end

    # Wordpress will sometimes use `wp:paragraph --&gt` for paragraphs, which should instead be <p>
    # `/wp:paragraph --&gt` should be </p>
    def self.handle_paragraph_tags(text)
      # Run this first to handle all closing tags (since the start and end share a lot of the same string)
      text = text.gsub "/wp:paragraph --&gt;", "</p>"
      # Handle open tags
      text = text.gsub "wp:paragraph --&gt;", "<p>"
      text
    end
end
