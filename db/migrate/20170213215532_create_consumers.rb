class CreateConsumers < ActiveRecord::Migration[4.2]
  def change
    create_table :consumers do |t|
      t.string    :uuid,       null: false
      t.datetime  :last_seen,  null: false
      t.integer   :times_seen, null: false, default: 0
      t.timestamps             null: false
    end
    
    add_index :consumers, :uuid, unique: true
  end
end
