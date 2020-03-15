# frozen_string_literal: true

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
  booleans = %w[true false]
  booleans.each do |boolean|
    languages = CMS.languages
    languages.each do |language|
      case cms_mode
      when :occrp_joomla
        response = controller.get_occrp_joomla_articles("language" => language, "categories" => boolean)
      when :wordpress
        response = Wordpress.articles("language" => language, "categories" => boolean)
      when :newscoop
        response = Newscoop.articles("language" => language, "categories" => boolean)
      when :cins_codeigniter
        response = CinsCodeigniter.articles("language" => language, "categories" => boolean)
      when :blox
        response = Blox.articles("language" => language, "categories" => boolean)
      end

      application_controller = ApplicationController.new

      if response[:results].class == Hash
        response[:results].keys.each do |key|
          # go through each image
          response[:results][key]&.each do |article|
            article["images"].each { |image| application_controller.passthrough_image(image["url"]) }
          end
        end
      end

      next unless response[:results].class == Array

      response[:results].each do |article|
        article["images"].each { |image| application_controller.passthrough_image(image["url"]) }
      end
    end
  end
end

unless defined?(Rails::Console) || File.split($PROGRAM_NAME).last == "rake"
  s.every "1m" do
    # run_update
  end
end
