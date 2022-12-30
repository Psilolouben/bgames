class AddScoreToBgame < ActiveRecord::Migration[7.0]
  def change
    add_column :bgames, :score, :float
  end
end
