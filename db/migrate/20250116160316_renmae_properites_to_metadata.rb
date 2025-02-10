class RenmaeProperitesToMetadata < ActiveRecord::Migration[7.0]
  def change
    c = MushafLineAlignment.connection
    c.add_column :mushaf_line_alignments, :meta_data, :jsonb, default: {}, if_not_exists: true

    c = Audio::ChapterAudioFile.connection
    c.rename_column :audio_chapter_audio_files, :metadata, :meta_data
  end
end
