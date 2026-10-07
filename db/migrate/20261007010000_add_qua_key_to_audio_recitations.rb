class AddQuaKeyToAudioRecitations < ActiveRecord::Migration[7.0]
  def change
    c = Audio::Recitation.connection
    return if c.column_exists?(:audio_recitations, :qua_key)

    c.add_column :audio_recitations, :qua_key, :string
    c.add_index :audio_recitations, :qua_key, unique: true
  end
end
