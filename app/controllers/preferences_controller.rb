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

    Setting.categories = params[:category].to_yaml
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
end
