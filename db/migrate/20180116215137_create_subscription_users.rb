class CreateSubscriptionUsers < ActiveRecord::Migration[5.1]
  def change
    create_table :subscription_users do |t|
      t.integer   :username,     null: false
      t.integer   :api_key
      t.timestamps
    end
  end
end
