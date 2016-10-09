class AddArticleIdToNotification < ActiveRecord::Migration
  def change
  	  add_column :notifications, :article_id, :string
  end
end
