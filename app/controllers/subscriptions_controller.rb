class SubscriptionsController < ApplicationController
  skip_before_action :verify_authenticity_token

  def authenticate
    
    user_name = params["username"]
    password = params["password"]
    
    @authenticated = false

    case @cms_mode 
      when :occrp_joomla
        render plain: "Not Implemented"
        return
      when :wordpress
        render plain: "Not Implemented"
        return
      when :newscoop
        render plain: "Not Implemented"
        return
      when :cins_codeigniter
        render plain: "Not Implemented"
        return
      when :blox
        @authenticated = Blox.authenticate(user_name, password, params)
    end
    
    respond_to do |format|
      format.json
    end
    
  end
end
