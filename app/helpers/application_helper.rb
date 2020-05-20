module ApplicationHelper
  def display_name_for_language(language)
    case language
    when "en"
      "English"
    when "bg"
      "Bulgarian"
    when "ru"
      "Russian"
    when "az"
      "Azerbaijani"
    when "sr"
      "Serbian"
    when "ro"
      "Romanian"
    else
      "Not Found"
    end
  end

  def check_for_valid_cms_mode
    case ENV["cms_mode"]
    when "occrp-joomla"
      :occrp_joomla
    when "wordpress"
      :wordpress
    when "newscoop"
      :newscoop
    when "cins-codeigniter"
      :cins_codeigniter
    when "blox"
      :blox
    when "snworks"
      :snworks
    else
      raise "CMS type #{ENV['cms_mode']} not valid for this version of Push."
    end
  end
end
