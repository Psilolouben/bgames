class CreateUnfoundBgames < ActiveRecord::Migration[7.0]
  def change
    create_table :unfound_bgames do |t|
      t.string :bgname
      t.string :string

      t.timestamps null: false
    end
  end
end
