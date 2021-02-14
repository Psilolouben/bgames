class AddInStockToBgame < ActiveRecord::Migration
  def change
    add_column :bgames, :in_stock, :boolean
  end
end
