class NotificationsController < ApplicationController

	skip_before_action :verify_authenticity_token, :only => ['subscribe', 'unsubscribe']
	before_action :authenticate_user!, :except => ['subscribe', 'unsubscribe']

	def index

	end

	def subscribe
		if(params["sandbox"] == "true")
	        options = {"service": "#{push_id}-ios-sandbox",
	        			 "subscriber": "#{params["dev_id"]}.#{params['language']}",
	        			 "pushservicetype": "apns",
	        			 "devtoken": params["dev_token"]
	        			}
	    else
	        options = {"service": "#{push_id}-ios",
			 "subscriber": "#{params["dev_id"]}.#{params['language']}",
			 "pushservicetype": "apns",
			 "devtoken": params["dev_token"]
			}
		end

		response = HTTParty.post("http://uniqush:9898/subscribe?#{options.to_query}", options)
    	response_json = JSON.parse(response.body)
    	logger.debug(response_json)

    	if(response_json["status"] == 1)
    		@status = "FAILURE"
			@uniqush_message = response_json['details']['errorMsg']    		
    		@status_id = 1
    	else
	    	# If the response is successful, save the device
			device = PushDevice.find_by_dev_id(params["dev_id"])
			if(!device)
				device = PushDevice.new({
					dev_id: params['dev_id'],
					dev_token: params['dev_token'],
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
		if(params["sandbox"] == "true")
	        options = {"service": "#{push_id}-ios-sandbox",
	        			 "subscriber": "#{params["dev_id"]}.#{params['language']}",
	        			 "pushservicetype": "apns",
	        			 "devtoken": params["dev_token"]
	        			}
	    else
	        options = {"service": "#{push_id}-ios",
			 "subscriber": "#{params["dev_id"]}.#{params['language']}",
			 "pushservicetype": "apns",
			 "devtoken": params["dev_token"]
			}
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

	def cert_upload
		#stub
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
