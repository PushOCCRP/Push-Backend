# frozen_string_literal: true

class AddStatusToPushDevice < ActiveRecord::Migration[4.2]
  def change
    add_column :push_devices, :status, :Integer, default: 0, null: false
  end
end
