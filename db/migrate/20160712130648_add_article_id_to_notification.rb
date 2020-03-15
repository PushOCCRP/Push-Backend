# frozen_string_literal: true

class AddArticleIdToNotification < ActiveRecord::Migration[4.2]
  def change
    add_column :notifications, :article_id, :string
  end
end
