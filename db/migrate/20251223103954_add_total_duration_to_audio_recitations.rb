class AddTotalDurationToAudioRecitations < ActiveRecord::Migration[7.0]
  def change
    c = Audio::Recitation.connection

    c.change_table :audio_recitations do |t|
      t.integer :total_duration, default: 0, null: false, index: true
    end
  end
end
