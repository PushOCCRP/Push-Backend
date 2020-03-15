class Notification < ActiveRecord::Base
  has_one :user

  def display_language
    case self.language
    when "en"
      language = "English"
    when "bg"
      language = "Bulgarian"
    when "ru"
      language = "Russian"
    when "az"
      language = "Azerbaijani"
    when "sr"
      language = "Serbian"
    when "ro"
      language = "Romanian"
    else
      language = "Not Found"
    end

    language
  end

  private
end
