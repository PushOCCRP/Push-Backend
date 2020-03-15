# frozen_string_literal: true

class CreateSubscriptionUsers < ActiveRecord::Migration[5.1]
  def change
    create_table :subscription_users do |t|
      t.string   :username, null: false
      t.string   :api_key
      t.timestamps
    end
  end
end
