class AnalyticsController < ApplicationController

	before_action :authenticate_user!

	def index
        @consumer_count = Consumer.all.count  	
        @consumer_count_last_day = Consumer.where(last_seen: 1.day.ago..Time.now).count
        @consumer_count_last_week = Consumer.where(last_seen: 1.week.ago..Time.now).count
        @consumer_count_last_month = Consumer.where(last_seen: 1.month.ago..Time.now).count
        
        @articles_request_count_last_day = ConsumerEvent.where(event_type_id: ConsumerEvent::EventType::ARTICLES_LIST, created_at: 1.day.ago..Time.now).count
        @articles_request_count_last_week = ConsumerEvent.where(event_type_id: ConsumerEvent::EventType::ARTICLES_LIST, created_at: 1.week.ago..Time.now).count
        @articles_request_count_last_month = ConsumerEvent.where(event_type_id: ConsumerEvent::EventType::ARTICLES_LIST, created_at: 1.month.ago..Time.now).count

        @article_view_count_last_day = ConsumerEvent.where(event_type_id: ConsumerEvent::EventType::ARTICLE_VIEW, created_at: 1.day.ago..Time.now).count
        @article_view_count_last_week = ConsumerEvent.where(event_type_id: ConsumerEvent::EventType::ARTICLE_VIEW, created_at: 1.week.ago..Time.now).count
        @article_view_count_last_month = ConsumerEvent.where(event_type_id: ConsumerEvent::EventType::ARTICLE_VIEW, created_at: 1.month.ago..Time.now).count

		@search_count_last_day = ConsumerEvent.where(event_type_id: ConsumerEvent::EventType::SEARCH, created_at: 1.day.ago..Time.now).count
		@search_count_last_week = ConsumerEvent.where(event_type_id: ConsumerEvent::EventType::SEARCH, created_at: 1.week.ago..Time.now).count
		@search_count_last_month = ConsumerEvent.where(event_type_id: ConsumerEvent::EventType::SEARCH, created_at: 1.month.ago..Time.now).count
		
		@notification_click_count_last_day = ConsumerEvent.where(event_type_id: ConsumerEvent::EventType::NOTIFICATION_CLICK, created_at: 1.day.ago..Time.now).count
		@notification_click_count_last_week = ConsumerEvent.where(event_type_id: ConsumerEvent::EventType::NOTIFICATION_CLICK, created_at: 1.week.ago..Time.now).count
		@notification_click_count_last_month = ConsumerEvent.where(event_type_id: ConsumerEvent::EventType::NOTIFICATION_CLICK, created_at: 1.month.ago..Time.now).count

		@social_media_share_count_last_day = ConsumerEvent.where(event_type_id: ConsumerEvent::EventType::SOCIAL_MEDIA_SHARE, created_at: 1.day.ago..Time.now).count
		@social_media_share_count_last_week = ConsumerEvent.where(event_type_id: ConsumerEvent::EventType::SOCIAL_MEDIA_SHARE, created_at: 1.week.ago..Time.now).count
		@social_media_share_count_last_month = ConsumerEvent.where(event_type_id: ConsumerEvent::EventType::SOCIAL_MEDIA_SHARE, created_at: 1.month.ago..Time.now).count

        @earliest_consumer_date = Consumer.first.nil? ? Time.now : Consumer.first.created_at 
        @earliest_consumer_event_date = ConsumerEvent.first.nil? ? Time.now : ConsumerEvent.first.created_at
        
        @most_recent_search_phrases = ConsumerEvent.where("event_type_id = #{ConsumerEvent::EventType::SEARCH} AND search_phrase <> ''").order(:created_at).limit(10)
        
		#add top 5 most viewed articles here..
		#@most_article_view = ConsumerEvent.group(:article).count.limit(5)        
	end

end
