class AddSurahInfoInLinealignment < ActiveRecord::Migration[7.0]
  def change
    add_column :mushaf_line_alignments, :meta_data, :jsonb, default: {}
  end
end
