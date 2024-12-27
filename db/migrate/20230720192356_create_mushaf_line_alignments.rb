class CreateMushafLineAlignments < ActiveRecord::Migration[7.0]
  def change
    create_table :mushaf_line_alignments do |t|
      t.integer :mushaf_id, index: true
      t.integer :page_number, index: true
      t.integer :line_number, index: true
      t.string :alignment

      t.timestamps
    end
  end
end
