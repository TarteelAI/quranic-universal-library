class CreateMorphologyDictionaryTermTranslations < ActiveRecord::Migration[7.0]
  def up
    c = Verse.connection

    c.create_table :morphology_dictionary_term_translations do |t|
      t.bigint :term_id, null: false
      t.string :locale, null: false
      t.string :title
      t.text :definition
      t.timestamps
    end

    c.add_index :morphology_dictionary_term_translations, :term_id
    c.add_index :morphology_dictionary_term_translations, [:term_id, :locale], unique: true, name: 'index_morph_dict_term_translations_on_term_and_locale'
  end

  def down
    c = Verse.connection
    c.drop_table :morphology_dictionary_term_translations, if_exists: true
  end
end

