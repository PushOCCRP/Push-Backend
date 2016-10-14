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
		@consolidated = Setting.consolidated_categories

		if(Setting.categories != nil)
			@selected_categories = Setting.categories.split('::')
		else
			@selected_categories = {}
		end
	end

	def update
		logger.debug(params)
		# We do it this way so that there's no extra blanks hanging out
		categories = ""
		params[:category].each do |category|
			if(categories.length != 0)
				categories += '::'
			end
			categories += category
		end

		Setting.categories = categories
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

end