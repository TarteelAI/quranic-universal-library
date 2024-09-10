class CreateTajweedWords < ActiveRecord::Migration[7.0]
  def change
    c = Word.connection

    c.create_table :tajweed_words do |t|
      t.belongs_to :mushaf, null: false, foreign_key: true
      t.belongs_to :word, null: false, foreign_key: true
      t.jsonb :letters, default: []
      t.string :text
      t.string :location, index: true

      t.timestamps
    end
  end
end
