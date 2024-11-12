class AddSourceToPhrase < ActiveRecord::Migration[7.0]
  def change
    add_column :morphology_phrases, :phrase_type, :integer
    add_column :morphology_phrases, :source, :integer

    add_index :morphology_phrases, :phrase_type
  end
end
