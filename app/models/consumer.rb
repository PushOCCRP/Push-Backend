class Consumer < ActiveRecord::Base
  has_many :consumer_events

  before_save do |consumer|
    consumer.last_seen = Time.now
  end
end
