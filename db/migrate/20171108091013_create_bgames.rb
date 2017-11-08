class CreateBgames < ActiveRecord::Migration
  def change
    create_table :bgames do |t|
      t.string :name
      t.integer :bgg_id

      t.timestamps null: false
    end
  end
end
