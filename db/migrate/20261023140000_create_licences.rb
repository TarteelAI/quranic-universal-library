class CreateLicences < ActiveRecord::Migration[8.0]
  def change
    create_table :licences do |t|
      t.string :name, null: false
      t.string :short_name
      t.string :url
      t.text :summary
      t.text :allowed
      t.text :allowed_with_permission
      t.text :prohibited
      t.text :conditions
      t.text :terms
      t.text :attribution
      t.text :copyright_holders
      t.string :contact
      t.text :credits
      t.text :special_thanks

      t.timestamps
    end

    change_table :resource_permissions do |t|
      t.references :licence, index: true
      t.text :attribution
      t.text :custom_terms
    end
  end
end
