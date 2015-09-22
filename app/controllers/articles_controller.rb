require 'net/http'

class ArticlesController < ApplicationController

  def index
    #http = Net::HTTP.new("joomla-docker-129154.nitrousapp.com")
    #request = Net::HTTP::Get.new("/index.php?option=com_push&format=json&view=articles")
    #uri = URI.parse("http://joomla-docker-129154.nitrousapp.com/index.php?option=com_push&format=json&view=articles")
    uri = URI.pars("https://www.google.com")
    # Shortcut
    @response_full = Net::HTTP.get_response(uri)
    #@response = JSON.parse(@response_full.body)
    #Rails.logger.info(@response_full)
    #@response = JSON.parse(http.request(request).body)
    @response = JSON.parse '{"results": [{"hello":""}, {"test":""}]}'
    #For the moment all images are empty, so we'll just leave this here
    @response['results'].each do |result|
      result['image_urls'] = []
    end

    logger.debug

    respond_to do |format|
      format.json
      format.html
    end
  end

  def search
    respond_to do |format|
      format.json
    end
  end

end
