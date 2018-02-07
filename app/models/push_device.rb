class PushDevice < ActiveRecord::Base
  
  module Status
    ACTIVE = 0
    DISABLED = 1
    SANDBOX = 2
    UNIQUSH = 3
  end

  module UniqushServiceType
  	GCM = 'gcm'
  	APNS = 'apns'
  	ANDROID = 'gcm'
  	IOS = 'ios'
  end

  def self.service_name platform, sandbox = false
  	service_name = PushDevice.push_id()
		
		if(platform == 'android')
			service_name += "-gcm"
			# All Android devices will use the same credentials, we seperate sandboxed later as a naming convention
		else
			service_name += "-ios"
			# iOS has seperate protocols for sandbox and production
			service_name += "-sandbox" if sandbox == true
		end
		
    return service_name
  end

	def self.push_id
		push_id = ENV['push_id']
		if(!push_id || push_id.length == 0)
			push_id = 'push_app'
		end

		return push_id
	end

	# Subscribe a new device, sandbox is for testing
	def subscribe_to_push sandbox = true
		return subscribe_unsubscribe_to_push false, sandbox
	end

	# Subscribe a new device, sandbox is for testing
	def unsubscribe_to_push sandbox = true
		response_json = subscribe_unsubscribe_to_push true, sandbox
		language = ''
		dev_token = ''
		save!
	end
  
  # This performs the actual call to subscribe or unsubscribe
	private def subscribe_unsubscribe_to_push unsubscribe, sandbox = true
		
		# build up the service name based on the platform
		# This is set up in the ENV variables
		service_name = PushDevice.service_name platform, sandbox

    
		# Build up the options that Uniqush needs
		# Subscriber has their language attached to the end of it so we can seperate it out
		options = { "service": service_name,
					      "subscriber": dev_id + "." + language
							}

		# Uniqush expects Android to use the "regid", iOS use the "devtoken"
		# We store them both under the same field in the database, and seperate them here
		case platform
		when 'android'
			options["regid"] = dev_token
			options["pushservicetype"] = PushDevice::UniqushServiceType::GCM
			# For Android, since there's not a built in sandbox, we just segregate it by naming convention
 			options[:subscriber] += ".sandbox" if sandbox == true
		when 'ios'
			options["devtoken"] = dev_token
      options["pushservicetype"] = PushDevice::UniqushServiceType::APNS
		end

		# Here we set the verb that's being used subscribe, or unsubscribe
		verb = unsubscribe == true ? 'unsubscribe' : 'subscribe'

		# Make the call to the Uniqush server
		logger.debug("#{unsubscribe == true ? "Unsubscribing" : "Subscribing"} to Uniqush with options: #{options}")
		response = HTTParty.post("http://uniqush:9898/#{verb}?#{options.to_query}", options)
		response_json = JSON.parse(response.body)
				
		logger.debug("*************************************")
		logger.debug("Device: #{self.inspect}")
		logger.debug("Uniqush response: #{response_json}")
		logger.debug("*************************************")
		
		# Parse through the message returned, building the JSON response
		if(response_json["status"] == 1)
			response = {status: "FAILURE", uniqush_message: response_json['details']['errorMsg'], status_id: 1}
		else
			response = {status: "SUCCESS", status_id: 0}
		end

		# Add in the Uniqush raw data for debugging purposes.
		response[:uniqush_code] = response_json['details']['code']
		response[:uniqush_response] = response_json

		# Send it all back up the chain
		return response
	end


end
