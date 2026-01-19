class CreateMorphologyGrammarTermTranslations < ActiveRecord::Migration[7.0]
  def up
    c = Verse.connection

    c.create_table :morphology_grammar_term_translations do |t|
      t.bigint :grammar_term_id, null: false
      t.string :locale, null: false
      t.string :title
      t.text :description
      t.timestamps
    end

    c.add_index :morphology_grammar_term_translations, :grammar_term_id
    c.add_index :morphology_grammar_term_translations,
                %i[grammar_term_id locale],
                unique: true,
                name: 'index_morph_grammar_term_translations_on_term_and_locale'
  end

  def down
    c = Verse.connection
    c.drop_table :morphology_grammar_term_translations, if_exists: true
  end
end

