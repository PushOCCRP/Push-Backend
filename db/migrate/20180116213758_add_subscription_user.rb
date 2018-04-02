class AddSubscriptionUser < ActiveRecord::Migration[5.1]
  def change
    create_table :subscription_user do |t|
      t.integer   :username,     null: false
      t.integer   :api_key
      t.timestamps               null: false
    end
  end
end
