# frozen_string_literal: true

class AddPushTimeToNotification < ActiveRecord::Migration[4.2]
  def change
    add_column :notifications, :push_time, :date
  end
end
