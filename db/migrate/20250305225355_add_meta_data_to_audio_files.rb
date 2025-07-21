class AddMetaDataToAudioFiles < ActiveRecord::Migration[7.0]
  def change
    c = AudioFile.connection
    c.add_column :recitations, :relative_path, :string, if_not_exists: true
    c.add_column :recitations, :name, :string, if_not_exists: true

    c.add_column :audio_files, :bit_rate, :float
    c.add_column :audio_files, :duration_ms, :integer
    c.add_column :audio_files, :meta_data, :jsonb, default: {}
    c.add_column :audio_files, :file_size, :integer
    c.add_column :audio_files, :has_repetition, :boolean, default: false
    c.add_column :audio_files, :repeated_segments, :string

    c.change_column :audio_files, :duration, :float
    c.add_column :audio_chapter_audio_files, :segments_count, :integer, default: 0

    c.add_column :audio_segments, :repeated_segments, :string
    c.add_column :audio_segments, :has_repetition, :boolean, default: false
    c.add_column :audio_segments, :segments_count, :integer, default: 0

    c.add_index :audio_segments, :has_repetition
    c.add_index :audio_files, :has_repetition
  end
end
