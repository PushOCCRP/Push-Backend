class ArticlesController < ApplicationController

  def index

    url = ENV['occrp_joomla_url']

    # Shortcut
    # We need the request to look like this, so we have to get the correct key.
    # At the moment it makes the call twice. We need to cache this.
    # response = HTTParty.get(url, headers: {'Cookie' => '6e5451c5a544c9e9a591c2fe3b28408c[lang]=en;'})
    response = HTTParty.get(url)
    cookies = response.headers['set-cookie']
    correct_cookie = nil
    cookies.split(', ').each do |cookie|
      if cookie.include? "[lang]"
        correct_cookie = cookie
        break
      end
    end
    response = HTTParty.get(url, headers: {'Cookie' => correct_cookie})
    body = response.body

    @response = JSON.parse(response.body)
    @response['results'].each do |result|

      #For the moment all images are empty, so we'll just leave this here
      result['image_urls'] = []

      # Just in case the dates are improperly formatted
      begin
        published_date = DateTime.strptime(result['publish_date'], '%F %T')
      rescue => error
        published_date = DateTime.new(1970,01,01)
      end
      # right now we only support dates on the mobile side, this will be time soon.
      #published_date = result['publish_date'].to_date
      result['publish_date'] = published_date.strftime("%Y%m%d")
    end

    respond_to do |format|
      format.json

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
