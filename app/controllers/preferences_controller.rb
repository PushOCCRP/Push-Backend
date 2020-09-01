class PreferencesController < ApplicationController
  before_action :authenticate_user!

  def index
    # make sure the ones in settings exists
    # split them with a delminator
    # in view, show drop downs
    # eventually make sure that doubles don't show up
    # save them again with the deliminator
    # make sure the requests include it, if wordpress (for now)
    @categories = get_categories
    @category_names = Setting.category_names
    @consolidated = Setting.consolidated_categories
    @show_most_recent = Setting.show_most_recent_articles

    # If this is redirected to from an error in the `update` method these will be set and are used on the
    # front end to display errors
    @validation_errors = flash[:validation_errors] unless flash[:validation_errors].nil?
    @categories = flash[:categories] unless flash[:categories].nil?

    @category_names = [] if @category_names.nil?

    @selected_categories = {}

    if Setting.categories.nil? == false
      @selected_categories = YAML.load(Setting.categories)
      @selected_categories = {} if @selected_categories.class == false.class
    end

    CMS.languages().each { |language| @selected_categories[language] = [] if @selected_categories.has_key?(language) && @selected_categories[language].blank? }

    if Setting.category_names != nil
      @category_names = YAML.load(Setting.category_names)
    else
      @category_names = {}
    end

    CMS.languages().each { |language| @category_names[language] = [] if @category_names[language].blank? }

    if ENV["cms_mode"] == "snworks"
      @language = "en"
      render template: "preferences/index_snworks"
    else
      render template: "preferences/index"
    end
  end

  def update
    # We do it this way so that there's no extra blanks hanging out
    params[:category].keys.each do |language|
      params[:category][language].delete_if { |category| category.blank? }
    end

    # Some CMS's support multiple languages, some don't. This fills the gaps so the processing later on doesn't care
    params[:category_name] = {} unless params.has_key?(:category_name)

    params[:category].keys.each do |language|
      # Same note as above regarding multiple languages
      params[:category_name][language] = [] unless params[:category_name].has_key?(language)
      params[:category][language].each_with_index do |category, index|
        # if there's no category name for this one, add it the params
        params[:category_name][language][index] = category if params[:category_name].blank? ||
                                                              params[:category_name][language].blank? ||
                                                              params[:category_name][language][index].blank?
      end
    end

    # Here we do some dancing around SNWorks
    validated_categories = validate_categories(params[:category])

    # This means there's a hash coming back, or something like a hash
    if validated_categories.respond_to? "keys"
      # Quick proc that checks every language and for a `invalid` hash, meaning something has to get fixed.
      contains_invalid_categories = ->(categories) {
        validated_categories.each do |key, value|
          return true unless value[:invalid].nil?
        end
        false
      }

      if contains_invalid_categories.call(validated_categories)
        # To make it the validation array on the front end make sense we need to dance around some stuff
        # This extracts only the `invalid` categories from the inputted
        validation_errors = validated_categories.map do |language, category_array|
          [language, category_array[:invalid]]
        end

        validation_errors = { categories: validation_errors }

        flash[:alert] = error_message_for_invalid_categories(validated_categories)

        # For showing validation on the front end
        flash[:validation_errors] = validation_errors
        flash[:categories] = validated_categories.map do |language, categories|
          { language.to_sym => categories[:categories] }
        end.reduce({}, :merge)

        redirect_to action: :index
        return
      end
    end

    Setting.categories = validated_categories.to_yaml
    Setting.category_names = params[:category_name].to_yaml

    Setting.consolidated_categories = params[:consolidated]
    Setting.show_most_recent_articles = params[:show_most_recent]

    Rails.cache.clear

    flash[:notice] = "Categories successfully updated"
    redirect_to action: :index
  end

private

  def get_categories
    case @cms_mode
    when :occrp_joomla
    # Not implemented yet
    when :wordpress
      response = Wordpress.categories
      logger.debug(response)
    when :newscoop
      response = Newscoop.categories
    when :cins_codeigniter
      # Not implemented yet
    when :blox
      response = Blox.categories
    when :snworks
      response = SNWorksCEO.categories
    end

    response
  end

  # Validate the categories are correct and valid and available.
  # Returns a list of categories properly formatted, or an error if something goes south.
  # Currently only available for SNWorks, all others return the same list.
  def validate_categories(categories)
    if ENV["cms_mode"] == "snworks"
      validated = {}
      categories.keys.each do |language|
        validated_categories = SNWorksCEO.validate_categories(categories[language])
        validated[language] = validated_categories[:invalid].empty? ? validated_categories[:categories] : validated_categories
      end
      return validated
    end

    # TODO: When adding support for other CMS's we'll refactor the caller of this to just expect the validation
    # hash instead of an array. However, that'd break the current implementation.
    categories
  end

  # Returns a string suitable for flash errors given a list of invalid categories
  def error_message_for_invalid_categories(categories)
    error = "Please fix the following problems:"
    # Cycle through all the languages
    # It may look like this: {"en"=>{:valid=>{"Sports"=>"Sports", "Arts"=>"arts"}, :invalid=>["something"]}}
    categories.each do |language, categories_for_language|
      # Go through each category in the languages
      categories_for_language[:invalid].each { |category| error += "<br>• #{language}: #{category} is not a valid category/tag name" }
    end
    error
  end
end
