class AddInStockToBgame < ActiveRecord::Migration[7.0]
  def change
    add_column :bgames, :in_stock, :boolean
  end
end
