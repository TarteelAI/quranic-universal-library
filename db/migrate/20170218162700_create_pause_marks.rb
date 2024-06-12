class CreatePauseMarks < ActiveRecord::Migration[5.0]
  def change
    create_table :pause_marks do |t|
      t.references :word
      t.string :verse_key
      t.integer :position
      t.string :mark

      t.timestamps
    end
  end
end
