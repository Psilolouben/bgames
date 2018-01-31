class RemoveDoubleFromBgame < ActiveRecord::Migration
  def change
    remove_column :bgames, :double, :string
  end
end
