class CreateUloomContents < ActiveRecord::Migration[7.0]
  def change
    create_table :uloom_contents do |t|
      t.text     :text,                null: false, index: true
      t.string   :cardinality_type,    index: true

      t.references :chapter,          null: false, index: true
      t.references :verse,                         index: true
      t.references :word,                          index: true
      t.references :resource_content, null: false, index: true

      t.string   :location,           index: true
      t.string   :location_range,     index: true
      t.jsonb    :meta_data, default: {}, null: false

      t.timestamps
    end
  end
end
