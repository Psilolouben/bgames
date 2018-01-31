class AddScoreToBgame < ActiveRecord::Migration
  def change
    add_column :bgames, :score, :double
  end
end
