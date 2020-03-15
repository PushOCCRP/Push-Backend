# frozen_string_literal: true

class Notification < ActiveRecord::Base
  has_one :user

  def display_language
    language = case language
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

    language
  end

  private
end
