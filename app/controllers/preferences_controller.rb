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

		if(Setting.categories != nil)
			@selected_categories = Setting.categories.split('::')
		else
			@selected_categories = {}
		end
	end

	def update
		
		if(params[:category].count != params[:category_name])
  		flash[:alert] = "Each category must have a display name"
  		redirect_to :back
  		return
    end
		
		# We do it this way so that there's no extra blanks hanging out
		categories = ""
		params[:category].each do |category|
			if(categories.length != 0)
				categories += '::'
			end
			categories += category
		end
		
 		category_names = ""
		params[:category_name].each do |category_name|
  		if(category_names != 0)
    		category_names += '::'
      end
      category_names += category_name
 		end

		Setting.categories = categories
		Setting.category_names = category_names
		Setting.consolidated_categories = params[:consolidated]

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
		# Not implemented yet
      when :cins_codeigniter
		# Not implemented yet
      end

      return response
	end
	
  def get_categories
	  case @cms_mode 
      when :occrp_joomla
		# Not implemented yet
	  when :wordpress
        response = Wordpress.categories
        response << 'post'
        logger.debug(response)
      when :newscoop
		# Not implemented yet
      when :cins_codeigniter
		# Not implemented yet
      end

      return response
	end


end