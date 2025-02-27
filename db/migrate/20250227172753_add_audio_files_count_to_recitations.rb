class AddAudioFilesCountToRecitations < ActiveRecord::Migration[7.0]
  def change
    c = Recitation.connection

    c.add_column :recitations, :files_count, :integer
    c.add_column :recitations, :segments_count, :integer, default: 0
    c.add_column :audio_files, :words_count, :integer
    c.add_column :audio_files, :segments_count, :integer, default: 0
  end
end
