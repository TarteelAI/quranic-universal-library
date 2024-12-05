class CreateDownloadableResourceTags < ActiveRecord::Migration[7.0]
  def change
    create_table :downloadable_resource_tags do |t|
      t.string :name, index: true
      t.string :glossary_term
      t.text :description
      t.string :color_class, default: 'blue'
      t.integer :resources_count
      t.string :slug, index: true

      t.timestamps
    end
  end
end