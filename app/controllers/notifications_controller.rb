class NotificationsController < ApplicationController

	skip_before_action :verify_authenticity_token, :only => ['subscribe', 'unsubscribe']
	before_action :authenticate_user!, :except => ['subscribe', 'unsubscribe']

	def index

	end

	def subscribe

		# build up the service name based on the platform, and if we're in the sandbox
		service_name = push_id
		push_service_type = "apns"
		if(params['platform'] == 'android')
			push_service_type = 'gcm'
			service_name += "-gcm"
		else
			service_name += "-ios"
		end

		if(params["sandbox"])
			service_name += "-sandbox"
		end

		# Build up the options
		options = {"service": service_name,
					"pushservicetype": push_service_type,
					"subscriber": "#{params["dev_id"]}.#{params['language']}"
				}

	    # Android uses the "regid", iOS use the "devtoken"
		case params["platform"]
		when 'android'
			options["regid"] = params["reg_id"]
		when 'ios'
			options["devtoken"] = params["dev_token"]
		end

		logger.debug("Subscribing to Uniqush with options: #{options}")
		# make the call!
		response = HTTParty.post("http://uniqush:9898/subscribe?#{options.to_query}", options)
    	response_json = JSON.parse(response.body)
    	logger.debug("Uniqush response: #{response_json}")

    	if(response_json["status"] == 1)
    		@status = "FAILURE"
			@uniqush_message = response_json['details']['errorMsg']    		
    		@status_id = 1
    	else
	    	# If the response is successful, save the device
			device = PushDevice.find_by_dev_id(params["dev_id"])
			if(!device)

				case params["platform"]
				when 'android'
					dev_token = params['regid']
				when 'ios'
					dev_token = params['dev_token']
				end


				device = PushDevice.new({
					dev_id: params['dev_id'],
					dev_token: dev_token,
					language: params['language'],
					platform: params['platform']
				})
			else
				device.language = params['language']
				device.save!
			end

			@status = "SUCCESS"
    		@status_id = 0
		end

   		@uniqush_code = response_json['details']['code']
		@uniqush_reponse = response_json
	end

	def unsubscribe
		# build up the service name based on the platform, and if we're in the sandbox
		service_name = push_id
		push_service_type = "apns"
		if(params['platform'] == 'android')
			push_service_type == 'gcm'
			service_name += "-gcm"
		else
			service_name += "-ios"
		end

		if(params["sandbox"])
			service_name += "-sandabox"
		end

		# Build up the options
		options = {"service": service_name,
					"pushservicetype": push_service_type,
					"subscriber": "#{params["dev_id"]}.#{params['language']}"
				}

	    # Android uses the "regid", iOS use the "devtoken"
		case params["platform"]
		when 'android'
			options["regid"] = params["reg_id"]
		when 'ios'
			options["devtoken"] = params["dev_token"]
		end


		response = HTTParty.post("http://uniqush:9898/unsubscribe?#{options.to_query}", options)
    	response_json = JSON.parse(response.body)
    	
    	if(response_json["status"] == 0)
    		@status == "FAILURE"
    		@uniqush_message = response_json['details']['errorMsg']    		
    		@status_id == 1
    	else
			device = PushDevice.find_by_dev_id(params["dev_id"])
			if(device)
				device.delete!
			end

			@status == "SUCCESS"
    		@status_id == 0
		end

	    @uniqush_code = response_json['details']['code']
		@uniqush_reponse = response_json
	end

	def gcm

	end

	def process_gcm
		Setting.gcm_project_id = params["project_id"]
		Setting.gcm_api_key_sandbox = params["api_key_sandbox"]
		Setting.gcm_api_key_production = params["api_key_production"]

		response_json = create_gcm_project(false)

    	if(response_json["status"] == 1)
    		flash[:error] = "Error updating gcm: #{response_json}"
    		redirect_to :gcm
    	else
			response_json = create_gcm_project(true)
	    	if(response_json["status"] == 1)
	    		flash[:error] = "Error updating gcm: #{response_json}"
	    		redirect_to :gcm
	    	else
    			flash[:notice] = "Successfully updated gcm"
    		end
		end

  		redirect_to 'index'
	end

	def create_gcm_project(sandbox=false)
		project_id = Setting.gcm_project_id
		if(sandbox)
			api_key = Setting.gcm_api_key_sandbox
		else
			api_key = Setting.gcm_api_key_production
		end

		service_name = "#{push_id}-gcm"
		if(!sandbox)
			service_name += "-sandbox"
		end

		options = {"service": service_name,
			 "pushservicetype": "gcm",
			 "projectid": project_id,
			 "apikey": api_key
		}

		response = HTTParty.get("http://uniqush:9898/addpsp?#{options.to_query}", options)
    	response_json = JSON.parse(response.body)

    	logger.debug("Create_gcm response: #{response_json}")

	    	if(response_json["status"] == 1)
    		raise("Error creating GCM service: #{response_json}")
    	else
    		if(sandbox)
    			Setting.gcm_name_sandbox = service_name
    		else
	    		Setting.gcm_name_production = service_name
	    	end
    	end

    	return response_json

	end

	def cert_upload
	end

	def process_cert
		sandbox_cert_io = params[:sandbox_cert]
		sandbox_key_io = params[:sandbox_key]
		production_cert_io = params[:production_cert]
		production_key_io = params[:production_key]


		filename = push_id

		sandbox_cert_file_name = "secrets/certs/#{filename}-sandbox-cert.pem"
		sandbox_key_file_name = "secrets/certs/#{filename}-sandbox-key.pem"
		production_cert_file_name = "secrets/certs/#{filename}-production-cert.pem"
		production_key_file_name = "secrets/certs/#{filename}-production-key.pem"

		File.open("/push/#{sandbox_cert_file_name}", 'wb') do |file|
			file.write(sandbox_cert_io.read)
		end

		File.open("/push/#{sandbox_key_file_name}", 'wb') do |file|
			file.write(sandbox_key_io.read)
		end

		File.open("/push/#{production_cert_file_name}", 'wb') do |file|
			file.write(production_cert_io.read)
		end

		File.open("/push/#{production_key_file_name}", 'wb') do |file|
			file.write(production_key_io.read)
		end


		Setting.sandbox_cert = sandbox_cert_file_name
		Setting.sandbox_key = sandbox_key_file_name
		Setting.production_cert = production_cert_file_name
		Setting.production_key = production_key_file_name

		response_json = create_apns(true)
		response_json = create_apns(false)

    	if(response_json["status"] == 1)
    		flash[:error] = "Error updating certs: #{@uniqush_message}"
    	else
    		flash[:notice] = "Successfully updated certs"
		end

		redirect_to 'cert_upload'
	end

	def create_apns(sandbox=false)
		service_name = "#{push_id}-ios"
		if(!sandbox)
			service_name += "-sandbox"
		end

		if(sandbox)
	        options = {"service": service_name,
			 "pushservicetype": "apns",
			 "cert": Setting.production_cert,
			 "key": Setting.production_key,
			}
		else
			options = {"service": service_name,
			 "pushservicetype": "apns",
			 "cert": Setting.sandbox_cert,
			 "key": Setting.sandbox_key,
			 "sandbox": "true"
			}
		end

		response = HTTParty.get("http://uniqush:9898/addpsp?#{options.to_query}", options)
    	response_json = JSON.parse(response.body)

    	logger.debug("Create_apns response: #{response_json}")

	    	if(response_json["status"] == 1)
    		raise("Error creating APNS service: #{response_json}")
    	else
    		Setting.apns_name_production = push_id
    		Setting.apns_name_sandbox = push_id
    	end

    	return response_json
	end

	def new
		@notification = Notification.new
	end

	def create
		@notification = Notification.new
		@notification.message = params[:notification][:message]
		@notification.language = params[:notification][:language]
		@notification.article_id = params[:notification][:article_id]
		@notification.save!

		redirect_to @notification
	end

	def show
		@notification = Notification.find(params[:id])
	end

	def push
		@notification = Notification.find(params[:id])

		if(params["sandbox"] == "true")
	        options = {"service": "#{push_id}-ios-sandbox",
	        			 "subscriber": "*.#{@notification.language}",
	        			 "msg": @notification.message,
	        			 "sound": 'default',
	        			 "article_id": @notification.article_id
	        			}
		else
	        options = {"service": "#{push_id}-ios",
			 "subscriber": "*.#{@notification.language}",
			 "msg": @notification.message,
			 "sound": 'default',
			 "article_id": @notification.article_id
			}
		end

		response = HTTParty.post("http://uniqush:9898/push?#{options.to_query}")
    	response_json = JSON.parse(response.body)
    	
    	if(response_json["status"] == 0)
    		@status == "FAILURE"
    		@uniqush_message = response_json['details']['errorMsg']    		
    		@status_id == 1
    		flash[:warning] = "Error: " + @uniqush_message
    	else
    		@notification.push_time = Time.now
    		@notification.save!

			@status == "SUCCESS"
    		@status_id == 0

    		flash[:notice] = "Successfully Pushed"

		end

	    @uniqush_code = response_json["status"]
		@uniqush_reponse = response_json

		redirect_to @notification
	end

  private

  def push_device_params
    params.require(:push_device).permit(:dev_id, :dev_token, :language, :platform)
  end

  def notification_params
    params.require(:notification).permit(:message, :language, :article_id)
  end


  def push_id
	push_id = ENV['push_id']
	if(!push_id || push_id.length == 0)
		push_id = 'push_app'
	end

	return push_id
  end


end
