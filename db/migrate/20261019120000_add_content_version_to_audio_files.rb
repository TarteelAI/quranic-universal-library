class AddContentVersionToAudioFiles < ActiveRecord::Migration[7.0]
  def change
    c = Audio::ChapterAudioFile.connection

    %i[audio_chapter_audio_files audio_files].each do |table|
      c.add_column table, :content_hash, :string, if_not_exists: true
      c.add_column table, :content_etag, :string, if_not_exists: true
      c.add_column table, :content_version, :bigint, if_not_exists: true
      c.add_column table, :content_updated_at, :datetime, if_not_exists: true
      c.add_column table, :content_version_source, :string, if_not_exists: true
    end
  end
end
