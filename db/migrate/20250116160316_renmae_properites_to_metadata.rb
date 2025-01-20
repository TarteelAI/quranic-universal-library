class RenmaeProperitesToMetadata < ActiveRecord::Migration[7.0]
  def change
    c = MushafLineAlignment.connection
    c.rename_column :mushaf_line_alignments, :properties, :meta_data

    c = Audio::ChapterAudioFile.connection
    c.rename_column :audio_chapter_audio_files, :metadata, :meta_data
  end
end
