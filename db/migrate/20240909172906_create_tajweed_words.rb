class CreateTajweedWords < ActiveRecord::Migration[7.0]
  def change
    c = Word.connection

    c.create_table :tajweed_words, if_not_exists: true do |t|
      t.belongs_to :mushaf, null: false, foreign_key: true
      t.belongs_to :word, null: false, foreign_key: true
      t.belongs_to :verse, null: false, foreign_key: true
      t.integer :resource_content_id

      t.jsonb :letters, default: []
      t.string :text
      t.string :location, index: true
      t.integer :position, index: true

      t.timestamps
    end
  end
end
