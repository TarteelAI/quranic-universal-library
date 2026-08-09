# frozen_string_literal: true

require_relative '../../test_helper'
require 'active_support/core_ext/object/blank'

module Arel
  def self.sql(value)
    value
  end
end unless defined?(Arel)

require_relative '../../../app/services/ayah_timestamp_verification/random_segment'

class RandomSegmentTest < Minitest::Test
  class WhereChain
    def initialize(relation)
      @relation = relation
    end

    def not(*)
      @relation
    end
  end

  class FakeRelation
    attr_reader :rows

    def initialize(rows)
      @rows = rows
    end

    def where(*args)
      return WhereChain.new(self) if args.empty?

      self
    end

    def exists?
      rows.any?
    end

    def order(*)
      self
    end

    def first
      rows.first
    end
  end

  FakeFile = Struct.new(:audio_url, keyword_init: true)
  FakeRecitation = Struct.new(:name, keyword_init: true)
  FakeVerse = Struct.new(:text_qpc_hafs, keyword_init: true)
  FakeSegment = Struct.new(
    :id,
    :timestamp_from,
    :timestamp_to,
    :verse,
    :audio_recitation,
    :audio_file,
    keyword_init: true
  )

  def setup
    @segment = FakeSegment.new(
      id: 1,
      timestamp_from: 100,
      timestamp_to: 500,
      verse: FakeVerse.new(text_qpc_hafs: 'بِسْمِ'),
      audio_recitation: FakeRecitation.new(name: 'Test Reciter'),
      audio_file: FakeFile.new(audio_url: 'https://example.com/a.mp3')
    )
  end

  def test_returns_payload_for_eligible_segment
    result = AyahTimestampVerification::RandomSegment.new(
      user: nil,
      scope: FakeRelation.new([@segment])
    ).call

    refute_nil result
    assert_equal @segment, result.segment
    assert_equal 'https://example.com/a.mp3', result.audio_url
    assert_equal 100, result.time_from
    assert_equal 500, result.time_to
  end

  def test_returns_nil_when_no_segments
    result = AyahTimestampVerification::RandomSegment.new(
      user: nil,
      scope: FakeRelation.new([])
    ).call

    assert_nil result
  end

  def test_returns_nil_when_audio_url_blank
    @segment.audio_file = FakeFile.new(audio_url: '')
    result = AyahTimestampVerification::RandomSegment.new(
      user: nil,
      scope: FakeRelation.new([@segment])
    ).call

    assert_nil result
  end
end
