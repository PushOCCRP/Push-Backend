require 'rufus-scheduler'

# Let's use the rufus-scheduler singleton
#
s = Rufus::Scheduler.singleton


# Stupid recurrent task...
#

def run_update
  puts "Running update for caches..."
  
  
  controller = ArticlesController.new
  cms_mode = ApplicationController.new.check_for_valid_cms_mode
  puts cms_mode
  case cms_mode 
    when :occrp_joomla
      response = controller.get_occrp_joomla_articles(nil)
    when :wordpress
      response = Wordpress.articles(nil)
    when :newscoop
      response = Newscoop.articles(nil)
    when :cins_codeigniter
      response = CinsCodeigniter.articles(nil)
    when :blox
      response = Blox.articles(nil)
  end
  
  application_controller = ApplicationController.new
  response[:results].keys.each do |key|
    #go through each image
    response[key].each do |article|
      article['images'].each{|image| application_controller.passthrough_image(image['url'])}
    end unless response[key].nil?
  end if response[:results].class == Hash
  
  response[:results].each do |article|
    article['images'].each{|image| application_controller.passthrough_image(image['url'])}
  end if response[:results].class == Array
  
end

return

unless defined?(Rails::Console) || File.split($0).last == 'rake'
  s.every '1m' do
    run_update
  end
end

