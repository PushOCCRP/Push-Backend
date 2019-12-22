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
end
