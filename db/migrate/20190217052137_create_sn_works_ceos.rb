class CreateSnWorksCeos < ActiveRecord::Migration[5.2]
  def change
    create_table :sn_works_ceos do |t|

      t.timestamps
    end
  end
end
