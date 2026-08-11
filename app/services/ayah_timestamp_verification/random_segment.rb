# frozen_string_literal: true

module AyahTimestampVerification
  class RandomSegment
    Result = Struct.new(
      :segment,
      :verse,
      :recitation,
      :audio_url,
      :time_from,
      :time_to,
      keyword_init: true,
    )

    def initialize(user: nil, scope: nil)
      @user = user
      @scope = scope || default_scope
    end

    def call
      segment = pick_segment
      return nil unless segment

      audio_url = segment.audio_file&.audio_url
      return nil if audio_url.blank?

      Result.new(
        segment: segment,
        verse: segment.verse,
        recitation: segment.audio_recitation,
        audio_url: audio_url,
        time_from: segment.timestamp_from,
        time_to: segment.timestamp_to,
      )
    end

    private

    attr_reader :user, :scope

    def pick_segment
      relation = scope
      relation = exclude_voted(relation) if user
      relation.order(Arel.sql('RANDOM()')).first
    end

    def exclude_voted(relation)
      voted_ids = AyahTimestampVote.where(user_id: user.id).select(:audio_segment_id)
      filtered = relation.where.not(id: voted_ids)
      filtered.exists? ? filtered : relation
    end

    def default_scope
      Audio::Segment
        .joins(:audio_recitation, :audio_file)
        .includes(:verse, :audio_recitation, :audio_file)
        .merge(Audio::Recitation.approved)
        .where.not(timestamp_from: nil, timestamp_to: nil)
        .where('audio_segments.timestamp_to > audio_segments.timestamp_from')
        .where.not(audio_chapter_audio_files: { audio_url: [nil, ''] })
    end
  end
end
