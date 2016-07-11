class NotificationsController < ApplicationController

	skip_before_action :verify_authenticity_token, :only => ['subscribe', 'unsubscribe']
	before_action :authenticate_user!, :except => ['subscribe', 'unsubscribe']

	def index

	end

	def create

	end

	def subscribe
        options = {"service": "#{push_id}-ios-sandbox",
        			 "subscriber": "#{params["dev_id"]}.#{params['language']}",
        			 "pushservicetype": "apns",
        			 "dev_token": params["dev_token"]
        			}

		response = HTTParty.post("http://uniqush:9898/subscribe", options)
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
        options = {"service": "#{push_id}-ios-sandbox",
        			 "subscriber": "#{params["dev_id"]}.#{params['language']}",
        			 "pushservicetype": "apns",
        			 "dev_token": params["dev_token"]
        			}

		response = HTTParty.post("http://uniqush:9898/unsubscribe", options)
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
		cert_io = params[:cert]
		key_io = params[:key]

		filename = push_id
		if(ENV['developer_mode'])
			filename += "-sandbox"
		end

		cert_file_name = "secrets/certs/#{filename}-cert.pem"
		key_file_name = "secrets/certs/#{filename}-key.pem"

		File.open("/push/#{cert_file_name}", 'wb') do |file|
			file.write(cert_io.read)
		end

		File.open("/push/#{key_file_name}", 'wb') do |file|
			file.write(key_io.read)
		end

		Setting.cert = cert_file_name
		Setting.key = key_file_name

		response_json = create_apns

    	if(response_json["status"] == 1)
    		flash[:error] = "Error updating certs: #{@uniqush_message}"
    	else
    		flash[:notice] = "Successfully updated certs"
		end

		redirect_to 'cert_upload'
	end

	def create_apns
		service_name = "#{push_id}-ios"
		if(ENV['developer_mode'])
			service_name += "-sandbox"
		end

		logger.debug("Development: #{ENV['developer_mode']}")
        options = {"service": service_name,
		 "pushservicetype": "apns",
		 "cert": Setting.cert,
		 "key": Setting.key,
		 "sandbox": ENV['developer_mode']
		}

		response = HTTParty.get("http://uniqush:9898/addpsp?#{options.to_query}", options)
    	response_json = JSON.parse(response.body)

    	logger.debug("Create_apns response: #{response_json}")

	    	if(response_json["status"] == 1)
    		raise("Error creating APNS service: #{response_json}")
    	else
    		Setting.apns_name = push_id
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
		@notification.save!

		redirect_to @notification
	end

	def show
		@notification = Notification.find(params[:id])
	end

	def push
		@notification = Notification.find(params[:id])

        options = {"service": "#{push_id}-ios-sandbox",
        			 "subscriber": "*.#{@notification.language}",
        			 "msg": @notification.message,
        			 "sound": 'default'
        			}

		response = HTTParty.post("http://uniqush:9898/push?#{options.to_query}")
    	response_json = JSON.parse(response.body)
    	
    	if(response_json["status"] == 0)
    		@status == "FAILURE"
    		@uniqush_message = response_json['details']['errorMsg']    		
    		@status_id == 1
    	else
    		@notification.push_time = Time.now
    		@notification.save!

			@status == "SUCCESS"
    		@status_id == 0
		end

	    @uniqush_code = response_json['details']['code']
		@uniqush_reponse = response_json

	end

  private

  def push_device_params
    params.require(:push_device).permit(:dev_id, :dev_token, :language, :platform)
  end

  def notification_params
    params.require(:notification).permit(:message, :language)
  end


  def push_id
	push_id = ENV['push_id']
	if(!push_id || push_id.length == 0)
		push_id = 'push_app'
	end

	return push_id
  end

end
