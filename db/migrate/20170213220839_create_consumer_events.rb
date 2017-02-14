class CreateConsumerEvents < ActiveRecord::Migration
  def change
    create_table :consumer_events do |t|
      t.integer   :consumer_id,     null: false
      t.integer   :event_type_id,   null: false
      t.integer   :article_id
      t.integer   :notification_id
      t.string    :language
      t.string    :search_phrase
      t.integer   :length
      t.timestamps                  null: false
      
    end
    
    add_index :consumer_events, :consumer_id
    add_index :consumer_events, :event_type_id
    add_index :consumer_events, :article_id
    add_index :consumer_events, :notification_id
  end
end
