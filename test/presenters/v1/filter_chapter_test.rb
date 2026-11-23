require 'minitest/autorun'
require 'active_support/core_ext/object/blank'

module Pagy
  module Backend; end
end unless defined?(Pagy::Backend)

module ActiveRecord
  class RecordNotFound < StandardError; end
end unless defined?(ActiveRecord::RecordNotFound)

module Api; end
require_relative '../../../lib/api/record_not_found'
require_relative '../../../app/presenters/application_presenter'
require_relative '../../../app/presenters/v1/api_presenter'

class FilterChapterTest < Minitest::Test
  def filter_chapter(params)
    presenter = V1::ApiPresenter.allocate
    presenter.instance_variable_set(:@params, params)
    presenter.send(:filter_chapter)
  end

  def test_returns_the_requested_chapter
    assert_equal 1, filter_chapter({ chapter: '1' })
    assert_equal 114, filter_chapter({ chapter: '114' })
    assert_equal 2, filter_chapter({ chapter_id: ' 2 ' })
    assert_equal 36, filter_chapter({ surah_number: 36 })
  end

  def test_returns_nil_without_a_chapter
    assert_nil filter_chapter({})
    assert_nil filter_chapter({ chapter: '' })
  end

  # A chapter outside 1-114 matched no verse, and translations/random and
  # tafsirs/random then called verse_key on nil, answering with a 500.
  def test_rejects_an_invalid_chapter
    %w[0 115 200 -5 abc 1abc].each do |value|
      error = assert_raises(Api::RecordNotFound, "expected #{value.inspect} to be rejected") do
        filter_chapter({ chapter: value })
      end
      assert_includes error.message, "#{value} Chapter ID or slug is invalid"
    end
  end
end
