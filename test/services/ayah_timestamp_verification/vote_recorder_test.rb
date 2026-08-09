# frozen_string_literal: true

require_relative '../../test_helper'
require 'active_support/core_ext/object/blank'
require 'ostruct'

module ActiveRecord
  class RecordNotUnique < StandardError; end
  class RecordInvalid < StandardError
    attr_reader :record

    def initialize(record)
      @record = record
      super('Record invalid')
    end
  end
end

class VoteRecorderTest < Minitest::Test
  class FakeErrors
    def initialize(messages)
      @messages = messages
    end

    def full_messages
      self
    end

    def to_sentence
      @messages.join(', ')
    end
  end

  class FakeVoteRecord
    attr_accessor :vote, :audio_recitation_id, :verse_key, :chapter_id, :verse_number

    def initialize
      @errors = FakeErrors.new([])
    end

    def errors
      @errors
    end

    def assign_attributes(attrs)
      attrs.each { |key, value| public_send("#{key}=", value) }
    end

    def save
      if %w[accurate inaccurate].include?(vote)
        true
      else
        @errors = FakeErrors.new(['Vote is invalid'])
        false
      end
    end

    def update!(attrs)
      assign_attributes(attrs)
      raise ActiveRecord::RecordInvalid, self unless save

      true
    end
  end

  FakeSegment = Struct.new(
    :id,
    :audio_recitation_id,
    :verse_key,
    :chapter_id,
    :verse_number,
    :timestamp_from,
    :timestamp_to,
    keyword_init: true
  )

  def setup
    @segments = [
      FakeSegment.new(
        id: 10,
        audio_recitation_id: 7,
        verse_key: '2:255',
        chapter_id: 2,
        verse_number: 255,
        timestamp_from: 1000,
        timestamp_to: 4000
      ),
      FakeSegment.new(
        id: 11,
        audio_recitation_id: 7,
        verse_key: '2:256',
        chapter_id: 2,
        verse_number: 256,
        timestamp_from: 5000,
        timestamp_to: 4000
      )
    ]
    @vote_store = []

    segment_model = Class.new do
      class << self
        attr_accessor :records

        def find_by(id:)
          (records || []).find { |row| row.id == id }
        end
      end
    end
    segment_model.records = @segments

    vote_model = Class.new do
      class << self
        attr_accessor :store

        def find_or_initialize_by(user_id:, audio_segment_id:)
          existing = store.find { |row| row[:user_id] == user_id && row[:audio_segment_id] == audio_segment_id }
          return existing[:record] if existing

          record = VoteRecorderTest::FakeVoteRecord.new
          store << { user_id: user_id, audio_segment_id: audio_segment_id, record: record }
          record
        end

        def find_by!(user_id:, audio_segment_id:)
          existing = store.find { |row| row[:user_id] == user_id && row[:audio_segment_id] == audio_segment_id }
          raise 'not found' unless existing

          existing[:record]
        end
      end

      const_set(:VOTES, %w[accurate inaccurate].freeze)
    end
    vote_model.store = @vote_store

    audio_module = Module.new
    audio_module.const_set(:Segment, segment_model)

    replace_const(:Audio, audio_module)
    replace_const(:AyahTimestampVote, vote_model)

    require_relative '../../../app/services/ayah_timestamp_verification/vote_recorder'
  end

  def test_rejects_invalid_vote_value
    result = AyahTimestampVerification::VoteRecorder.new(
      user: OpenStruct.new(id: 1),
      audio_segment_id: 10,
      vote: 'maybe'
    ).call

    refute result.success?
    assert_equal 'Invalid vote', result.error
  end

  def test_rejects_missing_segment
    result = AyahTimestampVerification::VoteRecorder.new(
      user: OpenStruct.new(id: 1),
      audio_segment_id: 999,
      vote: 'accurate'
    ).call

    refute result.success?
    assert_equal 'Segment not found', result.error
  end

  def test_rejects_invalid_timing
    result = AyahTimestampVerification::VoteRecorder.new(
      user: OpenStruct.new(id: 1),
      audio_segment_id: 11,
      vote: 'accurate'
    ).call

    refute result.success?
    assert_equal 'Segment timing is invalid', result.error
  end

  def test_creates_accurate_vote
    result = AyahTimestampVerification::VoteRecorder.new(
      user: OpenStruct.new(id: 1),
      audio_segment_id: 10,
      vote: 'accurate'
    ).call

    assert result.success?
    assert_equal 'accurate', result.vote.vote
    assert_equal 7, result.vote.audio_recitation_id
    assert_equal '2:255', result.vote.verse_key
  end

  def test_updates_existing_vote
    AyahTimestampVerification::VoteRecorder.new(
      user: OpenStruct.new(id: 1),
      audio_segment_id: 10,
      vote: 'accurate'
    ).call

    result = AyahTimestampVerification::VoteRecorder.new(
      user: OpenStruct.new(id: 1),
      audio_segment_id: 10,
      vote: 'inaccurate'
    ).call

    assert result.success?
    assert_equal 'inaccurate', result.vote.vote
    assert_equal 1, @vote_store.size
  end

  private

  def replace_const(name, value)
    Object.send(:remove_const, name) if Object.const_defined?(name)
    Object.const_set(name, value)
  end
end
