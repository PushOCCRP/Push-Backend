class PreferencesController < ApplicationController

	before_action :authenticate_user!

	def index
		#make sure the ones in settings exists
		#split them with a delminator
		#in view, show drop downs
		#eventually make sure that doubles don't show up
		#save them again with the deliminator
		#make sure the requests include it, if wordpress (for now)
		@categories = get_categories
    @category_names = Setting.category_names
		@consolidated = Setting.consolidated_categories
		@show_most_recent = Setting.show_most_recent_articles

    @category_names = [] if @category_names.nil?
    
		if(Setting.categories != nil)
			@selected_categories = YAML.load(Setting.categories)
		else
			@selected_categories = {}
		end

    CMS.languages().each{|language| @selected_categories[language] = [] if @selected_categories[language].blank?}


		if(Setting.category_names != nil)
	    @category_names = YAML.load(Setting.category_names)
    else
      @category_names = {}
    end
    
    CMS.languages().each{|language| @category_names[language] = [] if @category_names[language].blank?}

	end

	def update
		# We do it this way so that there's no extra blanks hanging out
		categories = ""    
    
    params[:category].keys.each do |language|
      params[:category][language].delete_if{|category| category.blank?}
    end

		params[:category].keys.each do |language|
 			index = 0	
  		params[:category][language].each do |category|  			
  			# if there's no category name for this one, add it the params
  			params[:category_name][language][index] = category if params[:category_name][language][index].blank?
  			index += 1
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
    end

    return response
	end
	
end