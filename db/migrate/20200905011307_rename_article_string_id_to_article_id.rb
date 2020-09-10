class RenameArticleStringIdToArticleId < ActiveRecord::Migration[5.2]
  def change
    rename_column :consumer_events, :article_string_id, :article_id
    add_index :consumer_events, :article_id
  end
end
