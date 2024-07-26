class CreateTajweedPositions < ActiveRecord::Migration[7.0]
  def change
    create_table :word_tajweed_positions do |t|
      t.string :audio
      t.string :location
      t.jsonb :positions
      t.jsonb :style
      t.string :word_group
      t.string :rule

      t.timestamps
    end
  end
end
