class CreateUloomContents < ActiveRecord::Migration[7.0]
  def change
    c = ActiveRecord::Base.connection
    c.create_table :uloom_contents do |t|
      t.text    :text,                index: true
      t.string  :cardinality_type,    index: true
      t.integer :chapter_id,          index: true
      t.integer :verse_id,            index: true
      t.integer :word_id,             index: true
      t.integer :resource_content_id, index: true
      t.string  :location,            index: true
      t.string  :location_range,      index: true

      t.jsonb   :meta_data,           default: {}, null: false

      t.timestamps
    end
  end
end
