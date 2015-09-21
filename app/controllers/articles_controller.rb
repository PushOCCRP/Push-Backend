class ArticlesController < ApplicationController

  def index
    http = Net::HTTP.new("joomla-docker-129154.nitrousapp.com")
    request = Net::HTTP::Get.new("/index.php?option=com_push&format=json&view=articles")
    @response = JSON.parse(http.request(request).body)

    #For the moment all images are empty, so we'll just leave this here
    @response['results'].each do |result|
      result['image_urls'] = []
    end
    
    respond_to do |format|
      format.json
    end
  end

  def search
    respond_to do |format|
      format.json
    end
  end

end
