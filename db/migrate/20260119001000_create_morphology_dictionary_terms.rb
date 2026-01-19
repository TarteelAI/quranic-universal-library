class CreateMorphologyDictionaryTerms < ActiveRecord::Migration[7.0]
  def up
    c = Verse.connection

    c.create_table :morphology_dictionary_terms do |t|
      t.string :category
      t.string :key, null: false, index: true
      t.timestamps
    end
  end

  def down
    c = Verse.connection
    c.drop_table :morphology_dictionary_terms, if_exists: true
  end
end

