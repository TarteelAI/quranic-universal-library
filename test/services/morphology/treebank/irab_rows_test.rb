require_relative '../../../test_helper'
require_relative '../../../../app/services/morphology/treebank/irab_rows'

class IrabRowsTest < Minitest::Test
  Token = Struct.new(
    :id, :token_type, :chapter_number, :verse_number, :word_number,
    :position_in_word, :head_token_id,
    keyword_init: true
  ) unless defined?(IrabRowsTest::Token)

  def surface(id:, chapter_number:, verse_number:, word_number:, position_in_word: 0, head_token_id: nil)
    Token.new(id: id, token_type: 'surface',
              chapter_number: chapter_number, verse_number: verse_number,
              word_number: word_number, position_in_word: position_in_word,
              head_token_id: head_token_id)
  end

  def hidden(id:, chapter_number:, verse_number:, word_number: nil, head_token_id: nil)
    Token.new(id: id, token_type: 'implicit_pronoun',
              chapter_number: chapter_number, verse_number: verse_number,
              word_number: word_number, position_in_word: 0,
              head_token_id: head_token_id)
  end

  def test_cross_verse_only_current_verse_becomes_rows
    tokens = [
      surface(id: 1, chapter_number: 1, verse_number: 2, word_number: 1),
      surface(id: 2, chapter_number: 1, verse_number: 3, word_number: 1),
      surface(id: 3, chapter_number: 1, verse_number: 4, word_number: 1),
    ]
    rows = Morphology::Treebank::IrabRows.new(tokens, chapter_number: 1, verse_number: 2).rows
    assert_equal 1, rows.size, "only verse 2 word 1 should become a row"
    assert_equal 1, rows.first[:word_tokens].first.id
  end

  def test_same_word_number_in_two_verses_not_merged
    tokens = [
      surface(id: 10, chapter_number: 1, verse_number: 2, word_number: 1),
      surface(id: 11, chapter_number: 1, verse_number: 2, word_number: 2),
      surface(id: 20, chapter_number: 1, verse_number: 3, word_number: 1),
    ]
    rows = Morphology::Treebank::IrabRows.new(tokens, chapter_number: 1, verse_number: 2).rows
    assert_equal 2, rows.size, "verse 2 has 2 distinct words → 2 rows"
    word_ids = rows.map { |r| r[:word_tokens].first.id }
    assert_includes word_ids, 10
    assert_includes word_ids, 11
    refute_includes word_ids, 20
  end

  def test_hidden_tokens_excluded_from_rows_but_present_in_head_map
    head = surface(id: 5, chapter_number: 1, verse_number: 2, word_number: 1)
    imp  = hidden(id: 6, chapter_number: 1, verse_number: 2, head_token_id: 5)
    tokens = [head, imp]
    obj = Morphology::Treebank::IrabRows.new(tokens, chapter_number: 1, verse_number: 2)
    rows = obj.rows
    assert_equal 1, rows.size, "implicit_pronoun must not become a row"
    assert_equal 5, rows.first[:word_tokens].first.id
    assert obj.head_map.key?(5), "surface token must be in head_map"
    assert obj.head_map.key?(6), "implicit token must also be in head_map for head lookups"
  end

  def test_rows_ordered_by_word_number
    tokens = [
      surface(id: 3, chapter_number: 1, verse_number: 2, word_number: 3),
      surface(id: 1, chapter_number: 1, verse_number: 2, word_number: 1),
      surface(id: 2, chapter_number: 1, verse_number: 2, word_number: 2),
    ]
    rows = Morphology::Treebank::IrabRows.new(tokens, chapter_number: 1, verse_number: 2).rows
    word_numbers = rows.map { |r| r[:word_tokens].first.word_number }
    assert_equal [1, 2, 3], word_numbers
  end

  def test_segments_ordered_by_position_in_word
    seg0 = surface(id: 10, chapter_number: 1, verse_number: 2, word_number: 1, position_in_word: 0)
    seg1 = surface(id: 11, chapter_number: 1, verse_number: 2, word_number: 1, position_in_word: 1)
    tokens = [seg1, seg0]
    rows = Morphology::Treebank::IrabRows.new(tokens, chapter_number: 1, verse_number: 2).rows
    assert_equal 1, rows.size
    assert_equal [10, 11], rows.first[:word_tokens].map(&:id)
  end
end
