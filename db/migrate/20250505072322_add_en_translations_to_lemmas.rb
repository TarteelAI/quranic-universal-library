class AddEnTranslationsToLemmas < ActiveRecord::Migration[7.0]
  def change
    c = Lemma.connection
    c.add_column :lemmas, :en_translations, :jsonb, default: [], null: false
  end
end
