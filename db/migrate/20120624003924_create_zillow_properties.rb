class CreateZillowProperties < ActiveRecord::Migration
  def change
    create_table :zillow_properties do |t|
      t.string  :address
      t.string  :url
      t.integer :price
      t.integer :zestimate
      t.integer :rentzestimate      
      t.integer :bedrooms
      t.float :bathrooms
      t.string :type
      
      t.timestamps
    end
  end
end
