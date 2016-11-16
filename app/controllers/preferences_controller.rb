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
			@selected_categories = Setting.categories.split('::')
		else
			@selected_categories = {}
		end
		
		
		if(Setting.category_names != nil)
	    @category_names = Setting.category_names.split('::')
    else
      @category_names = {}
    end
	end

	def update
		# We do it this way so that there's no extra blanks hanging out
		categories = ""
		index = 0
		params[:category].each do |category|
			if(categories.length != 0)
				categories += '::'
			end
			categories += category
			
			# if there's no category name for this one, add it the params
			#### NOTE: THIS IS BROKEN FIX NOW
			params[:category_name][index] = category if params[:category_name][index].blank?
			index += 1
		end

 		category_names = ""
		params[:category_name].each do |category_name|
  		if(category_names.length != 0)
    		category_names += '::'
      end
      category_names += category_name
 		end

		Setting.categories = categories
		Setting.category_names = category_names
		Setting.consolidated_categories = params[:consolidated]
    Setting.show_most_recent_articles = params[:show_most_recent]
    
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
      response << 'post'
      logger.debug(response)
    when :newscoop
      response = Newscoop.categories
    when :cins_codeigniter
		# Not implemented yet
    end

    return response
	end
	
end