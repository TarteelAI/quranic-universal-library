class AddAudioUrlToAudioFile < ActiveRecord::Migration[7.0]
  def change
    c = AudioFile.connection
    c.add_column :audio_files, :audio_url, :string
  end
end
