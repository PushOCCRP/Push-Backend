class ConsumerEvent < ActiveRecord::Base
  
  belongs_to :consumer
  has_one :article
  has_one :notification
  
  module EventType
    ARTICLES_LIST = 0
    ARTICLE_VIEW = 1
    SEARCH = 2
    NOTIFICATION_CLICK = 3
    SOCIAL_MEDIA_SHARE = 4
  end


end
