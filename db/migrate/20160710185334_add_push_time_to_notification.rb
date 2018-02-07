class AddPushTimeToNotification < ActiveRecord::Migration
  def change
  	add_column :notifications, :push_time, :date
  end
end
