class NotificationsController < ApplicationController

	#skip_before_action :verify_authenticity_token, :only => ['subscribe', 'unsubscribe']
	before_action :authenticate_user!, :except => ['subscribe', 'unsubscribe']

	def index
		@notifications = Notification.all.order(created_at: :desc)
	end

	def subscribe
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
		end

		device.save!

		response = subscribe_device device, params[:sandbox]
		@status = response[:status]
		@status_id = response[:status_id]
		@uniqush_code = response[:uniqush_code]
		@uniqush_message = response[:uniqush_message]
		@uniqush_response = response[:uniqush_response]
	end

	def resubscribe
		@devices = {successful: [], error: []}
		PushDevice.all.each do |device|
			response = subscribe_device device, params[:sandbox]
			case response[:status]
			when 0
				@devices[:successful] << device
			when 1
				@devices[:error] << device
			end
		end
	end

	def subscribe_device device, sandbox = true
		# build up the service name based on the platform, and if we're in the sandbox
		service_name = push_id
		push_service_type = "apns"
		if(device.platform == 'android')
			push_service_type = 'gcm'
			service_name += "-gcm"
		else
			service_name += "-ios"
		end

		if(sandbox == "true")
			service_name += "-sandbox"
		end

		# Build up the options
		options = {"service": service_name,
					"pushservicetype": push_service_type,
					"subscriber": "#{device_id}.#{language}"
				}

		# Android uses the "regid", iOS use the "devtoken"
		case platform
		when 'android'
			options["regid"] = device.dev_token
		when 'ios'
			options["devtoken"] = device.dev_token
		end

		logger.debug("Subscribing to Uniqush with options: #{options}")
		# make the call!
		response = HTTParty.post("http://uniqush:9898/subscribe?#{options.to_query}", options)
		response_json = JSON.parse(response.body)
		logger.debug("Uniqush response: #{response_json}")

		if(response_json["status"] == 1)
			response = {status: "FAILURE", uniqush_message: response_json['details']['errorMsg'], status_id: 1}
		else
			response = {status: "SUCCESS", status_id: 0}
		end

		response[:uniqush_code] = response_json['details']['code']
		response[:uniqush_response] = response_json

		return response
	end

	def unsubscribe
		# build up the service name based on the platform, and if we're in the sandbox
		service_name = push_id
		push_service_type = "apns"
		if(params['platform'] == 'android')
			push_service_type = 'gcm'
			service_name += "-gcm"
		else
			service_name += "-ios"
		end

		if(params["sandbox"] == "true")
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

		logger.debug("Unsubscribing to Uniqush with options: #{options}")
		# make the call!
		response = HTTParty.post("http://uniqush:9898/unsubscribe?#{options.to_query}", options)
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
					dev_token: '',
					language: '',
					platform: params['platform']
				})
			else
				device.language = ''
				device.dev_token = ''
			end

			device.save!

			@status = "SUCCESS"
			@status_id = 0
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

		redirect_to :cert_upload
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
		@notification.language = params[:notification][:language].downcase
		@notification.article_id = params[:notification][:article_id]
		@notification.save!

		redirect_to @notification
	end

	def show
		@notification = Notification.find(params[:id])
	end

	def push
		notification = Notification.find(params[:id])

		sandbox = to_boolean(params['sandbox'])

		ios_status = push_ios(notification, sandbox)
		android_status = push_gcm(notification, sandbox)

		if(ios_status == "SUCCESS" && android_status == "SUCCESS")
			flash[:notice] = "Successfully pushed"

			notification.push_time = Time.now
			notification.save!
		else
			error = ""
			if(ios_status != "SUCCESS")
				error += "iOS Error: #{ios_status} "
			end

			if(android_status != "SUCCESS")
				error += "Android Error: #{android_status}"
			end

			flash[:warning] = error
		end

		redirect_to notification
	end

	def push_ios(notification, sandbox=false)
		return build_push(notification, 'ios', sandbox)
	end

	def push_gcm(notification, sandbox=false)
		return build_push(notification, 'android', sandbox)
	end

	def build_push(notification, platform, sandbox)
		push_service_name = service_name(platform, sandbox)
		options = options_for_push(push_service_name, notification)
		return push_call options
	end

	def options_for_push(push_service_name, notification)
		options = {"service": push_service_name,
			 "subscriber": "*.#{notification.language}",
			 "msg": notification.message,
			 "sound": 'default',
			 "article_id": notification.article_id
			}
		return options
	end

	def push_call(options)
		response = HTTParty.post("http://uniqush:9898/push?#{options.to_query}")
		response_json = JSON.parse(response.body)
		
		logger.debug("Sending push with options: #{options}")

		if(response_json["status"] == 0)
			logger.debug("Uniqush Error: #{response_json}")
			return "Error: " + response_json['details']['errorMsg']
		else
			logger.debug("Push successful")
			return "SUCCESS"
		end
	end

	def admin
		@devices = PushDevice.all.count
		@ios_devices = PushDevice.where(platform: 'ios').count
		@android_devices = PushDevice.where(platform: 'android').count

		if(@ios_devices.nil?)
			@ios_devices = []
		end

		if(@android_devices.nil?)
			@android_devices = []
		end

		@status_check = check_push_status
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

	def service_name(platform, sandbox=false)
		service_name = push_id
		push_service_type = "apns"
		if(platform == 'android')
			push_service_type = 'gcm'
			service_name += "-gcm"
		else
			service_name += "-ios"
		end

		if(params["sandbox"])
			service_name += "-sandbox"
		end

		return service_name
	end

	def to_boolean(str)
		if(!str)
			return false
		end

		str.downcase == 'true'
	end

	def check_push_status
		statuses = {apns_prod: false, apns_sandbox: false, gcm_prod: false, gcm_sandbox: false}
		# Make a call to Uniqush to get stuff
		response = HTTParty.post("http://uniqush:9898/psps")
		response_json = JSON.parse(response.body)
		
		if(response_json["status"] == 0)
			logger.debug("Uniqush Error: #{response_json}")
			return statuses
		end

		logger.debug("Push successful")
		services = response_json['services']
		
		if(!response_json.has_key?('services'))
			return statuses
		end

		services = response_json['services']

		#check ios
		if(services.has_key?('push_app-ios') && services['push_app-ios'].size > 0)
			statuses[:apns_prod] = check_push_ios_status(services['push_app-ios'].first)
		end

		if(services.has_key?('push_app-ios-sandbox') && services['push_app-ios-sandbox'].size > 0)
			statuses[:apns_sandbox] = check_push_ios_status(services['push_app-ios-sandbox'].first)
		end

		#check android
		if(services.has_key?('push_app-gcm') && services['push_app-gcm'].size > 0)
			statuses[:gcm_prod] = check_push_android_status(services['push_app-gcm'].first)
		end

		if(services.has_key?('push_app-gcm-sandbox') && services['push_app-gcm-sandbox'].size > 0)
			statuses[:gcm_sandbox] = check_push_android_status(services['push_app-gcm-sandbox'].first)
		end

		return statuses
	end

	def check_push_ios_status service
		return check_push_response_status service, ['addr', 'cert', 'key', 'service']
	end

	def check_push_android_status service
		return check_push_response_status service, ['apikey', 'projectid', 'service']
	end

	def check_push_response_status service, required_keys
		# We explicity check for each key
		required_keys.each do |key|
			if(!service.has_key?(key))
				return false
			end
		end

		return true
	end

end
