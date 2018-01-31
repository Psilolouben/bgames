class AddVotersToBgame < ActiveRecord::Migration
  def change
    add_column :bgames, :voters, :integer
  end
end
