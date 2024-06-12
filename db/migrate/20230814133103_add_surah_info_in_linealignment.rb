class AddSurahInfoInLinealignment < ActiveRecord::Migration[7.0]
  def change
    add_column :mushaf_line_alignments, :properties, :jsonb, default: {}
  end
end
