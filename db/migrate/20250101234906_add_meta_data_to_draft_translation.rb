class AddMetaDataToDraftTranslation < ActiveRecord::Migration[7.0]
  def change
    c = Draft::Translation.connection
    c.add_column :draft_translations, :meta_data, :jsonb, default: {}, if_not_exists: true
    c.add_column :draft_tafsirs, :meta_data, :jsonb, default: {}, if_not_exists: true

    c = MushafLineAlignment.connection
    c.add_column :mushaf_line_alignments, :meta_data, :jsonb, default: {}, if_not_exists: true
  end
end
