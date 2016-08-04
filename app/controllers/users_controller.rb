class UsersController < ApplicationController
    rescue_from ActionController::RedirectBackError, with: :redirect_to_default
    rescue_from ActiveRecord::RecordNotFound, with: :user_not_found

	before_action :authenticate_user!
	before_action :set_minimum_password_length, only: [:new, :edit]

	def index
		@users = User.all
		@devise_error_messages = []
	end

	def new
		@user = User.new
	end

	def create

		u = User.new(:email => params[:user][:email], :password => params[:user][:password], :password_confirmation => params[:user][:password_confirmation])

		if(u == false)
			@devise_error_messages = u.errors
			redirect_to new_user_path(u)
		end
		u.save!

		flash[:notice] = "#{u.email} successfully created."

		redirect_to u
	end


	def show
		@user = User.find(params[:id])
	end

	def edit
		@user = User.find(params[:id])

		if(current_user != @user)
			flash[:alert] = "You can only edit yourself. Please contact the administrator with questions."
			redirect_to :users
		end
	end

	def update
		@user = User.find(params[:id])

		if(current_user != @user)
			flash[:alert] = "You can only edit yourself. Please contact the administrator with questions."
			redirect_to :users
		end

		if(params[:user][:password] != params[:user][:password_confirmation])
			flash[:alert] = "Passwords must match."
			redirect_to :back
		end

		@user.email = params[:user][:email]
		if(!params[:user][:password].blank?)
			@user.password = params[:user][:password]
		end

		@user.save!

		sign_in(@user, :bypass => true)

		flash[:notice] = "Successfully updated user."
		redirect_to @user
	end

	def destroy
		user = User.find(params[:id])

		email = user.email
		user.destroy!

		flash[:notice] = "#{email} deleted"
		redirect_to :back
	end

	private

    def redirect_to_default
    	redirect_to users_path
  	end
  	
  	def user_not_found
		flash[:alert] = "User not found with id #{params[:id]}"
		begin
			redirect_to :back
		rescue ActionController::RedirectBackError
			redirect_to_default
		end
  	end

  	def set_minimum_password_length
  		@minimum_password_length = 10
  	end

end
