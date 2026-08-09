# frozen_string_literal: true

class CreateAyahTimestampVotes < ActiveRecord::Migration[8.0]
  def change
    create_table :ayah_timestamp_votes do |t|
      t.bigint :user_id, null: false
      t.bigint :audio_recitation_id, null: false
      t.bigint :audio_segment_id, null: false
      t.string :verse_key, null: false
      t.integer :chapter_id, null: false
      t.integer :verse_number, null: false
      t.string :vote, null: false

      t.timestamps
    end

    add_index :ayah_timestamp_votes, [:user_id, :audio_segment_id], unique: true,
              name: 'index_ayah_timestamp_votes_on_user_and_segment'
    add_index :ayah_timestamp_votes, :vote
    add_index :ayah_timestamp_votes, :audio_recitation_id
    add_index :ayah_timestamp_votes, :verse_key
    add_index :ayah_timestamp_votes, :user_id
  end
end
