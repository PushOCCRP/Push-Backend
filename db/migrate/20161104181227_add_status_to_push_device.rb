class AddStatusToPushDevice < ActiveRecord::Migration
  def change
 	  add_column :push_devices, :status, :Integer, :default => 0, :null => false
  end
end
