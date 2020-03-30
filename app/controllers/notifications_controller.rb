class NotificationsController < ApplicationController
  # skip_before_action :verify_authenticity_token, :only => ['subscribe', 'unsubscribe']
  before_action :authenticate_user!, except: ["subscribe", "unsubscribe"]

  skip_before_action :verify_authenticity_token, only: ["subscribe", "unsubscribe"]
  def index
    @notifications = Notification.all.order(created_at: :desc)
  end

  # Subscribes a device to the Uniqush push system.
  # This should be called every time devices receives a new token, usually this happens
  # when opening a new session, or sometimes randomly when the OS decides it should.
  # This also should happen when changing languages, since it'll be a different channel.
  def subscribe
    # Parse out the request parameters
    # These might be passed as a JSON body or as request parameters
    begin
      params = JSON.parse(request.body.string)
    rescue Exception
      params = request.request_parameters
    end

    # Do a check for the required parameters, returning an error if there's something wrong
    if params["dev_id"].nil? || params["platform"].nil? || params["language"].nil?
      render json: { "status": "Missing required parameters" }
      return
    end

    # Lets turn this into a booleans so we're not doing string comparison later on.
    sandbox = params["sandbox"] == "true" ? true : false

    # We need to set the dev token which is generated by the iOS or Android apps
    # This is used to identify that permissions were properly granted by the user
    # They can revoke this, in which case there will be an error later, but nothing
    # bad will happen
    case params["platform"]
    when "android"
      # the old versions of the Android app had 'regid'
      dev_token = params["regid"] if params.has_key? "regid"
      dev_token = params["reg_id"] if params.has_key? "reg_id"
    when "ios"
      dev_token = params["dev_token"]
    end


    # Here we try and find a device in our database. If it doesn't exist we create it.
    device = PushDevice.find_by_dev_id(params["dev_id"]) if !params["dev_id"].nil?
    if !device
      device = PushDevice.new({
        dev_id: params["dev_id"],
        dev_token: dev_token,
        platform: params["platform"]
      })
    else
      # There's already a device, we should unsubscribe it from the channel it's already in
      # This is so that we make up any differences in the Uniqush server and ours.
      # I wish there was a way to check, but it doesn't seem as if there is.
      device.platform = params["platform"]
      device.save!
      device.unsubscribe_to_push(params["sandbox"])
    end

    # Update the device with the new language and dev token
    device.language = params["language"]
    device.dev_token = dev_token

    # If this is a sandbox'd test device, we'll set the appropriate status and save it all up.
    device.status = sandbox == true ? PushDevice::Status::SANDBOX : PushDevice::Status::ACTIVE
    device.save!

    # Now that all that's done, we make the call.
    response = device.subscribe_to_push(sandbox)

    # Set all the response variables from the Uniqush status.
    @status = response[:status]
    @status_id = response[:status_id]
    @uniqush_code = response[:uniqush_code]
    @uniqush_message = response[:uniqush_message]
    @uniqush_response = response[:uniqush_response]
  end

  # This unsubscribes a device from Uniqush, it should be called before resubscribing.
  # Note: Subscribe automatically unsubscribes a device as well, but this is left in for
  # legacy purposes.
  def unsubscribe
    # Parse out the request parameters
    # These might be passed as a JSON body or as request parameters
    begin
      params = JSON.parse(request.body.string)
    rescue Exception
      params = request.request_parameters
    end

    # Do a check for the required parameters, returning an error if there's something wrong
    if params["dev_id"].nil? || params["platform"].nil?
      render json: { "status": "Missing required parameters" }
      return
    end

    # Lets turn this into a booleans so we're not doing string comparison later on.
    sandbox = params["sandbox"] == "true" ? true : false

    # Find the device in our system.
    device = PushDevice.find_by_dev_id(params["dev_id"])

    if !device
      # If there's no device in the database but it's still trying unsubscribe it means it
      # does infact exist and should be saved as a new device, just blank.
      PushDevice.new({
        dev_id: params["dev_id"],
        dev_token: "",
        language: "",
        platform: params["platform"]
      })
      response_json = { "details": { "code": 0 } }
    else
      # If there is a device, we run unsubscribe on it.
      response_json = device.unsubscribe_to_push(sandbox)
    end

    # Set the variables properly
    @uniqush_code = response_json["details"]["code"]
    @uniqush_reponse = response_json
  end

  # This is used to resubscribe every user in the database. Useful if something goes terribly wrong
  # with the Uniqush server.
  #
  # Warning: Right now this is done synchronously, which is really fucking dangerous
  # if someone runs in this in production it could take a long time and freeze the entire system
  # this needs to be put into an ActionJob ASAP
  def resubscribe
    # This will keep track of all the statuses
    @devices = { successful: [], error: [] }

    # Run through every single device and subscribe them again
    PushDevice.all.each do |device|
      is_sandboxed = case device.status
                     when PushDevice::Status::SANDBOX then true
                     when PushDevice::Status::ACTIVE then false
                     else false
      end

      # This makes the call to subscribe and stores the device in a box or not
      # It returns a structure so that we can evaluate what went wrong too.
      response = device.subscribe_to_push is_sandboxed
      case response[:status]
      when 0 then @devices[:successful] << { device: device, response: response }
      when 1 then @devices[:error] << { device: device, response: response }
      else @devices[:error] << { device: device, response: response }
      end
    end
  end



  # def unsubscribe_device device, sandbox = "true"
  #   # build up the service name based on the platform, and if we're in the sandbox
  #   service_name = push_id

  #   if(device.platform == 'android')
  #     push_service_type = 'gcm'
  #     service_name += "-gcm"
  #   else
  #     push_service_type = "apns"
  #     service_name += "-ios"
  #     service_name += "-sandbox" if sandbox == "true"
  #   end

  #   # Build up the options
  #   options = {"service": service_name,
  #         "pushservicetype": push_service_type,
  #         "subscriber": device.dev_id + "." + device.language
  #       }

  #   # Android uses the "regid", iOS use the "devtoken"
  #   # This seems to have changed
  #   case device.platform
  #   when 'android'
  #     options["regid"] = device.dev_token

  #     # For Android, since there's not a built in sandbox, we just segregate it
  #     if(sandbox == "true")
  #       options[:subscriber] += ".sandbox"
  #     end
  #   when 'ios'
  #     options["devtoken"] = device.dev_token
  #   end

  #   logger.debug("Unsubscribing to Uniqush with options: #{options}")
  #   # make the call!
  #   response = HTTParty.post("http://uniqush:9898/unsubscribe?#{options.to_query}", options)
  #   response_json = JSON.parse(response.body)

  #   logger.debug("*************************************")
  #   logger.debug("Device: #{device.inspect}")
  #   logger.debug("Uniqush response: #{response_json}")
  #   logger.debug("*************************************")

  #   if(response_json["status"] == 1)
  #     response = {status: "FAILURE", uniqush_message: response_json['details']['errorMsg'], status_id: 1}
  #   else
  #     response = {status: "SUCCESS", status_id: 0}
  #   end

  #   response[:uniqush_code] = response_json['details']['code']
  #   response[:uniqush_response] = response_json

  #   return response
  # end

  # This is a page for updating GCM credentials from the Firebase Console
  # There's some stuff in here for FCM but it is not supported, and might never be at this point
  # DO NOT USE FCM, the old style works just fine for now.
  def gcm
    # The product id. It'll look like "install-test-28f2e"
    @gcm_project_id = Setting.gcm_project_id
    # The API key. Google referes to this as the "legacy" key, and it's found on the "Cloud Messaging"
    # tab in the Firebase Console.
    @gcm_api_key = Setting.gcm_api_key

    @fcm_api_key_sandbox = Setting.fcm_api_key_sandbox       # Ignore these
    @fcm_api_key_production = Setting.fcm_api_key_production # Ignore these
  end

  # This will save and process the GCM keys, persisting them to memory, and calling
  # the Uniqush commands to create it.
  def process_gcm
    Setting.gcm_project_id = params["project_id"]
    Setting.gcm_api_key = params["gcm_api_key"]

    Setting.fcm_api_key_sandbox = params["fcm_api_key_production"]    # Ignore these
    Setting.fcm_api_key_production = params["fcm_api_key_production"] # Ignore these
    response_json = create_gcm_project

    if response_json["status"] == 1
      flash[:error] = "Error updating gcm: #{response_json}"
      redirect_to :gcm
    else
      flash[:notice] = "Successfully updated gcm and fcm"
    end

    redirect_to action: :gcm
  end

  # Here we call the Uniqush commands. Might be better to put this in a helper?
  private def create_gcm_project
    # First we pull the saved credentials
    project_id = Setting.gcm_project_id
    api_key = Setting.gcm_api_key

    # If something went terribly wrong raise an error.
    raise "GCM Credentials not properly stored" if project_id.nil? || api_key.nil?

    # GCM only uses one pipe, so we can just make the name here.
    service_name = PushDevice.service_name("android")

    # Create the options for the GCM services
    options = { "service": service_name,
       "pushservicetype": PushDevice::UniqushServiceType::GCM,
       "projectid": project_id,
       "apikey": api_key
    }

    # Make the call
    response = HTTParty.get("http://uniqush:9898/addpsp?#{options.to_query}", options)
    response_json = JSON.parse(response.body)

    logger.debug("*************************************")
    logger.debug("Create_gcm response: #{response_json}")
    logger.debug("*************************************")


    if response_json["status"] == 1
      logger.debug("*************************************")
      logger.debug("Error Creating GCM service: #{response_json}")
      logger.debug("*************************************")

      raise("Error creating GCM service: #{response_json}")
    else
      # Save it to the persistent memory
      Setting.gcm_name = service_name
    end

    # Send it back up
    response_json
  end


  #########
  # APNS
  #########

  # A stub to show the cert upload page
  def cert_upload
    # Here we should set up the current certs, including figuring out their status as valid/invalid
  end

  # This processes the uploading of the APNS certificate and key
  # They both have to be .pem files, which is very confusing
  # You should use Fastlane's PEM tool https://docs.fastlane.tools/actions/pem/
  #
  # After creating it with PEM you need to convert the certificate (the .p12 file) to a .pem format.
  # Note: Make sure you name the key and cert something so you can tell the difference, otherwise you WILL
  # get it confused.

  # To do that here's the steps (probably, need to be reviewed again):
  # 1.) Export the key
  # % openssl pkcs12 -in apns-prod-key.p12 -out apns-prod-key.pem
  # Enter Import Password:
  #   <hit enter: the p12 has no password>
  # MAC verified OK
  # Enter PEM pass phrase:
  #   <enter a temporary password to encrypt the pem file>
  #
  # 2.) Strip the password
  # % openssl rsa -in apns-prod-key.pem -out apns-prod-key-noenc.pem
  #
  #
  # Eventually I want to make it so this is all done automatically
  # NOTE: This is done now automatically in the Push Generator with the '-c' flag

  def process_cert
    flash[:error] = "No file selected for the cert" if params[:cert].nil?
    flash[:error] = "No file selected for the key" if params[:key].nil?
    redirect_to action: :cert_upload unless flash[:error].blank?

    cert_io = params[:cert]
    key_io = params[:key]

    # Get the name of the push service we're using
    filename = PushDevice.push_id()

    cert_file_name = "/secrets/certs/#{filename}-cert.pem"
    key_file_name = "/secrets/certs/#{filename}-key.pem"

    FileUtils.mkdir_p("/push/secrets/certs") unless File.directory?("/push/secrets/certs")

    # Upload the files
    File.open("/push#{cert_file_name}", "wb") do |file|
      file.write(cert_io.read)
    end

    File.open("/push#{key_file_name}", "wb") do |file|
      file.write(key_io.read)
    end

    # Save the cert and key file names to the settings
    Setting.cert = cert_file_name
    Setting.key = key_file_name

    # Here we create the APNS services, one sandboxed, one not
    begin
      response_json = create_apns(true)
      response_json = create_apns(false)
    rescue
      # Probable errors are not finding the files properly, but maybe other stuff too?
      flash[:error] = "Error updating certs: #{@uniqush_message}"
      response_json = { "status": 1 }
    end

    # Handle errors returning from Uniqush
    if response_json["status"] == 1
      flash[:error] = "Error updating certs: #{@uniqush_message}"
    else
      flash[:notice] = "Successfully updated certs"
    end

    # Redirect to the cert upload page
    redirect_to action: :cert_upload
  end

  # This is used to make the call to Uniqush to create the APNS servivce, sandbox is optional
  def create_apns(sandbox = false)
    service_name = PushDevice.service_name("ios", sandbox)

    # Create the options to create the service
    options = { "service": service_name,
     "pushservicetype": PushDevice::UniqushServiceType::APNS,
     "cert": Setting.cert,
     "key": Setting.key,
    }

    # APNS takes a sandbox option if we want
    options[:sandbox] = true if sandbox

    # Make the call and create it all.
    response = HTTParty.get("http://uniqush:9898/addpsp?#{options.to_query}", options)
    response_json = JSON.parse(response.body)

    logger.debug("*************************************")
    logger.debug("Create_apns response: #{response_json}")
    logger.debug("*************************************")


    # Parse the response, if we're good, save it all
    if response_json["status"] == 1
      raise("Error creating APNS service: #{response_json}")
    else
      Setting.apns_name_production = PushDevice.push_id if sandbox == false
      Setting.apns_name_sandbox = PushDevice.push_id if sandbox == true
    end

    # Send it all back up
    response_json
  end

  #############
  # Notifications
  #############

  # For creating a new Notification
  def new
    @notification = Notification.new
    # This is to show only available languages
    @languages = CMS.languages()
  end

  # Create a new notification here
  def create
    # Save all the notifications coming through

    # TODO: Check languages here
    error_message = "Message cannot be empty" if params[:notification][:message].blank?
    error_message = "Language cannot be empty" if params[:notification][:language].blank?
    error_message = "Article ID cannot be empty" if params[:notification][:article_id].blank?

    if !error_message.blank?
      flash.now[:alert] = error_message
      render :new
      return
    end

    @notification = Notification.new
    @notification.message = params[:notification][:message]
    @notification.language = params[:notification][:language].downcase
    @notification.article_id = params[:notification][:article_id]
    @notification.save!

    redirect_to @notification
  end

  # Show a single notification, usually to review before pushing it out
  def show
    @notification = Notification.find(params[:id])
  end

  # Push out the notification to the users
  def push
    # Get the notification
    notification = Notification.find(params[:id])

    # Is this going to our test devices?
    sandbox = to_boolean(params["sandbox"])

    # Push the notifications out to iOS and Android services
    ios_status = push_ios(notification, sandbox)
    android_status = push_android(notification, sandbox)

    # If they're both successfull then great job!
    if ios_status == "SUCCESS" && android_status == "SUCCESS"
      flash[:notice] = "Successfully pushed"

      # Save the notification so we know when it was pushed.
      notification.push_time = Time.now
      notification.save!
    else
      # If there's an error we check both iOS an Android status
      error = ""
      if ios_status != "SUCCESS"
        error += "iOS Error: #{ios_status} "
      end

      if android_status != "SUCCESS"
        error += "Android Error: #{android_status}"
      end

      flash[:warning] = error
    end

    # In the end go back to the notification
    redirect_to notification
  end

  # Push out the iOS notification
  def push_ios(notification, sandbox = false)
    build_push(notification, "ios", sandbox)
  end

  # Push out the Android notification
  def push_android(notification, sandbox = false)
    build_push(notification, "android", sandbox)
  end

  # Since pushing is the same for both services with just different data, we consolidate the code here
  def build_push(notification, platform, sandbox)
    # First get the name of the service we are sending to
    push_service_name = PushDevice.service_name(platform, sandbox)

    # Let's get the options that will be send for the message
    options = options_for_push(push_service_name, platform, notification, sandbox)

    # Make the push and return it
    push_call options, platform
  end

  # Get the options for the push call given the fields
  def options_for_push(push_service_name, platform, notification, sandbox = false)
    options = { "service": push_service_name,
       "subscriber": "*.#{notification.language}",
       "msg": notification.message,
       "sound": "default",
       "article_id": notification.article_id,
       "language": notification.language
    }

    # If we're pushing to an android device then we need to check the sandbox
    if platform == "android"
      options[:subscriber] += ".sandbox" if sandbox == true
    end

    options
  end

  # Make the actual call and handle errors
  def push_call(options, platform)
    logger.debug("Sending #{platform} push with options: #{options}")

    response = HTTParty.post("http://uniqush:9898/push?#{options.to_query}")
    response_json = JSON.parse(response.body)

    logger.debug("*************************************")
    logger.debug("Uniqush response: #{response_json}")
    if response_json["status"] == 0
      logger.debug("Error: #{response_json}")
      logger.debug("*************************************")

      "Error: " + response_json["details"]["errorMsg"]
    else
      logger.debug("Push successful")
      logger.debug("*************************************")

      "SUCCESS"
    end
  end

  #  def push_call_android_fcm options, sandbox, notification
  #    api_key = Setting.fcm_api_key_production
  #    if(sandbox == true)
  #      api_key = Setting.fcm_api_key_sandbox
  #    end
  #    fcm = FCM.new(api_key)
  #    #Redo the options for FireBase
  #    if(sandbox == true)
  #      status = PushDevice::Status::SANDBOX
  #    else
  #      status = PushDevice::Status::ACTIVE
  #    end
  #    registration_ids = PushDevice.where(platform: "android", language: notification.language, status: status).map{|device| device.dev_token}
  #    push_options = {
  #      data: {message: options[:msg], article_id: options[:article_id], sound: options[:sound]},
  #      priority: 'high'
  #    }
  #    logger.debug("Sending FCM push with options: #{push_options}")
  #    response = fcm.send(registration_ids, push_options)
  #    # If there's an error with anything fail out
  #    if(response[:status_code] != 200)
  #      logger.debug("Error: #{response}")
  #      return "Error: " + response[:body]
  #    end
  #    response_json = JSON.parse(response[:body])
  #    # Here we should go through the "results" array and check for errors, removing any that have the "error" key
  #    index = 0
  #    response_json["results"].each do |result|
  #      if(result.has_key? "error")
  #        #look at the regisration_ids to get the registration id that's bad
  #        registration_id = registration_ids[index]
  #        device = PushDevice.where(dev_id: registration_id).first
  #        next if device.nil?
  #        device.status = PushDevice::Status::DISABLED
  #        logger.debug("Disable #{device.id} error: #{result["error"]}")
  #        device.save!
  #      end
  #      index += 1
  #    end
  #    logger.debug("Push successful")
  #    return "SUCCESS"
  #  end

  # Displays the admin page.
  def admin
    @devices = PushDevice.all.count
    @ios_devices = PushDevice.where(platform: "ios").count
    @android_devices = PushDevice.where(platform: "android").count

    if @ios_devices.nil?
      @ios_devices = []
    end

    if @android_devices.nil?
      @android_devices = []
    end

    @status_check = check_push_status
  end

private

  # This is for the security purposes
  def push_device_params
    params.require(:push_device).permit(:dev_id, :dev_token, :language, :platform)
  end

  def notification_params
    params.require(:notification).permit(:message, :language, :article_id)
  end

  def to_boolean(str)
    if !str
      return false
    end

    str.downcase == "true"
  end

  # Check the status of the various parts of the push system.
  # TODO: check status of push app cert
  def check_push_status
    statuses = { apns_prod: false, apns_sandbox: false, gcm_legacy: false, gcm_firebase: false }
    # Make a call to Uniqush to get stuff
    response = HTTParty.post("http://uniqush:9898/psps")
    response_json = JSON.parse(response.body)

    if response_json["status"] == 0
      logger.debug("Uniqush Error: #{response_json}")
      return statuses
    end

    logger.debug("Push successful")

    if !response_json.has_key?("services")
      return statuses
    end

    services = response_json["services"]

    # check ios
    if services.has_key?("push_app-ios") && services["push_app-ios"].size > 0
      statuses[:apns_prod] = check_push_ios_status(services["push_app-ios"].first)
    end

    if services.has_key?("push_app-ios-sandbox") && services["push_app-ios-sandbox"].size > 0
      statuses[:apns_sandbox] = check_push_ios_status(services["push_app-ios-sandbox"].first)
    end

    # check android
    if services.has_key?("push_app-gcm") && services["push_app-gcm"].size > 0
      statuses[:gcm] = check_push_android_status(services["push_app-gcm"].first)
    end

    statuses
  end

  def check_push_ios_status(service)
    check_push_response_status service, ["addr", "cert", "key", "service"]
  end

  def check_push_android_status(service)
    check_push_response_status service, ["apikey", "projectid", "service"]
  end

  # Run through the keys looking for the right one
  def check_push_response_status(service, required_keys)
    # We explicity check for each key
    required_keys.each { |key| return false if !service.has_key?(key) }
    true
  end
end
