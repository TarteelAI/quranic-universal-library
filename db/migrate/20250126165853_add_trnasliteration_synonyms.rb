class AddTrnasliterationSynonyms < ActiveRecord::Migration[7.0]
  def change
    add_column :synonyms, :en_transliterations, :jsonb, default: []
    ActiveRecord::Migration.add_column :synonyms, :text_simple, :string
    ActiveRecord::Migration.add_column :synonyms, :text_uthmani, :string
    ActiveRecord::Migration.add_column :synonyms, :words_count, :integer, default: 0
    ActiveRecord::Migration.add_column :synonyms, :approved, :boolean, default: false

  end
end
