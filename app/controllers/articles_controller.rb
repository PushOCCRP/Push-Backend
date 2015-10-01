class ArticlesController < ApplicationController

  def index
    #http = Net::HTTP.new("joomla-docker-129154.nitrousapp.com")
    #request = Net::HTTP::Get.new("/index.php?option=com_push&format=json&view=articles")
    #uri = URI.parse("http://joomla-docker-129154.nitrousapp.com/index.php?option=com_push&format=json&view=articles")
    url = "http://joomla-docker-129154.nitrousapp.com/index.php?option=com_push&format=json&view=articles"
    # Shortcut
    response = HTTParty.get(url)

    @response = JSON.parse(response.body)
    #For the moment all images are empty, so we'll just leave this here
    @response['results'].each do |result|
      result['image_urls'] = []
      published_date = result['publish_date'].to_date
      result['publish_date'] = published_date.to_formatted_s(:number)
    end

    respond_to do |format|
      format.json
      format.html
    end
  end

  def search
    #http = Net::HTTP.new("joomla-docker-129154.nitrousapp.com")
    #request = Net::HTTP::Get.new("/index.php?option=com_push&format=json&view=articles")
    #uri = URI.parse("http://joomla-docker-129154.nitrousapp.com/index.php?option=com_push&format=json&view=articles")
    url = "http://joomla-docker-129154.nitrousapp.com/index.php?option=com_push&format=json&view=search&query=#{params[:query]}"
    # Shortcut
    response = HTTParty.get(url)
    @response = JSON.parse(response.body)
    #For the moment all images are empty, so we'll just leave this here
    @response['results'].each do |result|
      result['image_urls'] = []
      #published_date = result['publish_date'].to_date
      #result['publish_date'] = published_date.to_formatted_s(:number)
    end

    respond_to do |format|
      format.json
    end
  end

end
