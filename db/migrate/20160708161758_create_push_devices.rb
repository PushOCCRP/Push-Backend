class CreatePushDevices < ActiveRecord::Migration
  def change
    create_table :push_devices do |t|
      t.string :dev_token
      t.string :dev_id
      
      t.string :language

      t.string :platform

      t.timestamps null: false
    end
  end
end
