class AddHeadlineToNotification < ActiveRecord::Migration[5.2]
  def change
    add_column :notifications, :headline, :string
  end
end
