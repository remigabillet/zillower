class RenameTypeColumn < ActiveRecord::Migration
  def up
    rename_column :zillow_properties, :type, :property_type
  end

  def down
  end
end
