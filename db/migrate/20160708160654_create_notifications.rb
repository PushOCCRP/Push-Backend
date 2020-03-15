# frozen_string_literal: true

class CreateNotifications < ActiveRecord::Migration[4.2]
  def change
    create_table :notifications do |t|
      add_reference :users, index: true, foreign_key: true

      t.text :message
      t.string :language

      t.integer :reach

      t.timestamps null: false
    end
  end
end
