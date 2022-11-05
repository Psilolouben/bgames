class RemoveDoubleFromBgame < ActiveRecord::Migration[7.0]
  def change
    remove_column :bgames, :double, :string
  end
end
