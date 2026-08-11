class AddLetterSegmentsToAudioSegments < ActiveRecord::Migration[7.0]
  def change
    c = Audio::Segment.connection
    c.add_column :audio_segments, :letter_segments, :jsonb
  end
end
