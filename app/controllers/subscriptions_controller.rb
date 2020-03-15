# frozen_string_literal: true

class SubscriptionsController < ApplicationController
  skip_before_action :verify_authenticity_token

  def authenticate
    username = params["username"]
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
      @authenticated = Blox.authenticate(username, password, params)
    end

    # If the user is properly authenticated against the server then we either return the previous api_key or
    # make the user anew and return that.
    @subscription_user = SubscriptionUser.where(username: username).first_or_create!

    respond_to do |format|
      format.json
    end
  end

  def logout
    render json: return_error("username missing") unless params.has_key("username")
    render json: return_error("api_key missing") unless params.has_key("api_key")

    user = SubscriptionUser.find(username: params["username"], api_key: ["api_key"])
    user.generate_api_key
    user.save!
  end
end
