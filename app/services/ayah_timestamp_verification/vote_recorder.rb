# frozen_string_literal: true

module AyahTimestampVerification
  class VoteRecorder
    Result = Struct.new(:success?, :vote, :error, keyword_init: true)

    def initialize(user:, audio_segment_id:, vote:)
      @user = user
      @audio_segment_id = audio_segment_id
      @vote = vote.to_s
    end

    def call
      return failure('Invalid vote') unless AyahTimestampVote::VOTES.include?(@vote)

      segment = Audio::Segment.find_by(id: @audio_segment_id)
      return failure('Segment not found') unless segment
      return failure('Segment timing is invalid') unless valid_timing?(segment)

      persist(segment)
    rescue ActiveRecord::RecordNotUnique
      retry_update(segment)
    end

    private

    def persist(segment)
      record = find_or_build_vote(segment)
      assign_vote_attributes(record, segment)

      if record.save
        Result.new(success?: true, vote: record, error: nil)
      else
        failure(record.errors.full_messages.to_sentence.presence || 'Could not save vote')
      end
    end

    def find_or_build_vote(segment)
      AyahTimestampVote.find_or_initialize_by(
        user_id: @user.id,
        audio_segment_id: segment.id,
      )
    end

    def assign_vote_attributes(record, segment)
      record.assign_attributes(
        audio_recitation_id: segment.audio_recitation_id,
        verse_key: segment.verse_key,
        chapter_id: segment.chapter_id,
        verse_number: segment.verse_number,
        vote: @vote,
      )
    end

    def valid_timing?(segment)
      segment.timestamp_from.present? &&
        segment.timestamp_to.present? &&
        segment.timestamp_to > segment.timestamp_from
    end

    def retry_update(segment)
      record = AyahTimestampVote.find_by!(user_id: @user.id, audio_segment_id: segment.id)
      record.update!(vote: @vote)
      Result.new(success?: true, vote: record, error: nil)
    rescue ActiveRecord::RecordInvalid => e
      failure(e.record.errors.full_messages.to_sentence)
    end

    def failure(message)
      Result.new(success?: false, vote: nil, error: message)
    end
  end
end
