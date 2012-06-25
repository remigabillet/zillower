class AddMoreFields < ActiveRecord::Migration
  def up
    add_column :zillow_properties, :sq_ft, :integer
    add_column :zillow_properties, :photo_url, :string
  end

  def down
  end
end
