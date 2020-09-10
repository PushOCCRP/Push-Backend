class ConvertConsumerArticleIdToString < ActiveRecord::Migration[5.2]
  def up
    add_column :consumer_events, :article_string_id, :string

    ConsumerEvent.all.each do |consumer_event|
      consumer_event.update!({ article_string_id: "#{consumer_event.article_id}" })
    end

    remove_column :consumer_events, :article_id
  end

  def down
    fail "Migration is irreversible"
  end
end
