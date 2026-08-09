# frozen_string_literal: true

# == Schema Information
#
# Table name: ayah_timestamp_votes
#
#  id                   :bigint           not null, primary key
#  chapter_id           :integer          not null
#  verse_key            :string           not null
#  verse_number         :integer          not null
#  vote                 :string           not null
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#  audio_recitation_id  :bigint           not null
#  audio_segment_id     :bigint           not null
#  user_id              :bigint           not null
#
# Indexes
#
#  index_ayah_timestamp_votes_on_audio_recitation_id       (audio_recitation_id)
#  index_ayah_timestamp_votes_on_user_and_segment          (user_id,audio_segment_id) UNIQUE
#  index_ayah_timestamp_votes_on_user_id                   (user_id)
#  index_ayah_timestamp_votes_on_verse_key                 (verse_key)
#  index_ayah_timestamp_votes_on_vote                      (vote)
#

class AyahTimestampVote < ApplicationRecord
  VOTES = ['accurate', 'inaccurate'].freeze

  belongs_to :user

  validates :audio_recitation_id, :audio_segment_id, :verse_key, :chapter_id, :verse_number, presence: true
  validates :vote, inclusion: { in: VOTES }
  validates :audio_segment_id, uniqueness: { scope: :user_id }
end
