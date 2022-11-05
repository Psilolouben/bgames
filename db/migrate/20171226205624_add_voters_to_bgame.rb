class AddVotersToBgame < ActiveRecord::Migration[7.0]
  def change
    add_column :bgames, :voters, :integer
  end
end
