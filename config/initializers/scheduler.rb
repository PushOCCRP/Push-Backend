require "rufus-scheduler"

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

  # We run through a bunch of possibilities here making sure we cache everything we can.
  booleans = ["true", "false"]
  booleans.each do |boolean|
    languages = CMS.languages
    languages.each do |language|
      case cms_mode
      when :occrp_joomla
        response = controller.get_occrp_joomla_articles({ "language" => language, "categories" => boolean })
      when :wordpress
        response = Wordpress.articles({ "language" => language, "categories" => boolean })
      when :newscoop
        response = Newscoop.articles({ "language" => language, "categories" => boolean })
      when :cins_codeigniter
        response = CinsCodeigniter.articles({ "language" => language, "categories" => boolean })
      when :blox
        response = Blox.articles({ "language" => language, "categories" => boolean })
      end

      application_controller = ApplicationController.new

      response[:results].keys.each do |key|
        # go through each image
        response[:results][key].each do |article|
          article["images"].each { |image| application_controller.passthrough_image(image["url"]) }
        end unless response[:results][key].nil?
      end if response[:results].class == Hash

      response[:results].each do |article|
        article["images"].each { |image| application_controller.passthrough_image(image["url"]) }
      end if response[:results].class == Array
    end
  end
end

unless defined?(Rails::Console) || File.split($0).last == "rake"
  s.every "1m" do
    # run_update
  end
end
