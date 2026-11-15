require_relative '../../../test_helper'
require_relative '../../../../app/services/morphology/treebank/irab_line'
require_relative '../../../../app/services/morphology/treebank/irab_rows'

class IrabRowsTest < Minitest::Test
  Token = Struct.new(
    :id, :token_type, :sentence_id, :chapter_number, :verse_number, :word_number,
    :position_in_word, :position_in_sentence, :head_token_id, :rel_label, :rel_governor,
    :constituent_label, :constituent_span_start, :constituent_span_end, :source_meta,
    keyword_init: true
  ) unless defined?(IrabRowsTest::Token)

  def surface(id:, chapter_number: 1, verse_number: 2, word_number:, position_in_word: 0, **rest)
    Token.new(id: id, token_type: 'surface', sentence_id: 1,
              chapter_number: chapter_number, verse_number: verse_number,
              word_number: word_number, position_in_word: position_in_word,
              position_in_sentence: id, **rest)
  end

  def hidden(id:, chapter_number: 1, verse_number: 2, **rest)
    Token.new(id: id, token_type: 'implicit_pronoun', sentence_id: 1,
              chapter_number: chapter_number, verse_number: verse_number,
              word_number: nil, position_in_word: 0, position_in_sentence: id, **rest)
  end

  def rows_for(tokens, verse_number: 2)
    Morphology::Treebank::IrabRows.new(tokens, chapter_number: 1, verse_number: verse_number)
  end

  # The tree above the table draws the whole sentence, so the table covers
  # every ayah of it, and flags the one the page is for.
  def test_all_verses_of_the_sentence_become_rows
    tokens = [
      surface(id: 1, verse_number: 2, word_number: 1),
      surface(id: 2, verse_number: 3, word_number: 1),
      surface(id: 3, verse_number: 4, word_number: 1)
    ]
    rows = rows_for(tokens, verse_number: 3).rows
    assert_equal %w[1:2 1:3 1:4], rows.map { |r| r[:verse_key] }
    assert_equal [false, true, false], rows.map { |r| r[:current] }
  end

  def test_same_word_number_in_two_verses_not_merged
    tokens = [
      surface(id: 20, verse_number: 3, word_number: 1),
      surface(id: 10, verse_number: 2, word_number: 1),
      surface(id: 11, verse_number: 2, word_number: 2)
    ]
    rows = rows_for(tokens).rows
    assert_equal [10, 11, 20], rows.map { |r| r[:word_tokens].first.id }
  end

  def test_hidden_tokens_excluded_from_rows_but_present_in_head_map
    head = surface(id: 5, word_number: 1)
    imp  = hidden(id: 6, head_token_id: 5)
    obj = rows_for([head, imp])
    assert_equal 1, obj.rows.size, 'implicit_pronoun must not become a row'
    assert obj.head_map.key?(5)
    assert obj.head_map.key?(6), 'implicit token must also be in head_map for head lookups'
  end

  def test_segments_ordered_by_position_in_word
    seg0 = surface(id: 10, word_number: 1, position_in_word: 0)
    seg1 = surface(id: 11, word_number: 1, position_in_word: 1)
    rows = rows_for([seg1, seg0]).rows
    assert_equal [10, 11], rows.first[:word_tokens].map(&:id)
  end

  # 11:3 — اسْتَغْفِرُوا رَبَّكُمْ is a VS spanning tokens 30..33 whose line
  # NoorBayan puts under token 33 (loc1), i.e. the word رَبَّكُمْ.
  def test_phrase_line_attaches_to_loc1_word
    verb   = surface(id: 30, word_number: 2, constituent_label: 'VS', constituent_span_start: 30,
                     constituent_span_end: 33, source_meta: { 'loc1' => '33' })
    suffix = surface(id: 31, word_number: 2, position_in_word: 1)
    noun   = surface(id: 32, word_number: 3)
    pron   = surface(id: 33, word_number: 3, position_in_word: 1)
    obj = rows_for([verb, suffix, noun, pron])

    by_word = obj.rows.to_h { |r| [r[:word_tokens].first.word_number, r[:phrase_tokens].map(&:id)] }
    assert_equal({ 2 => [], 3 => [30] }, by_word)
    assert obj.phrase_head?(verb)
    refute obj.phrase_head?(noun)
    assert_equal [30, 31, 32, 33], obj.span_tokens(verb).map(&:id).sort
  end

  def test_phrase_anchor_skips_hidden_tokens
    verb = surface(id: 1, word_number: 1, constituent_label: 'VS', constituent_span_start: 1,
                   constituent_span_end: 2, source_meta: { 'loc1' => '2' })
    pron = hidden(id: 2, head_token_id: 1)
    obj = rows_for([verb, pron])
    assert_equal [1], obj.rows.first[:phrase_tokens].map(&:id)
  end

  def test_predicate_for_bare_pred_only
    subject = surface(id: 1, word_number: 1, rel_label: 'root')
    pred    = surface(id: 2, word_number: 2, rel_label: 'pred', head_token_id: 1)
    kana    = surface(id: 3, word_number: 3, rel_label: 'root')
    kpred   = surface(id: 4, word_number: 4, rel_label: 'pred', rel_governor: 'كان', head_token_id: 3)
    obj = rows_for([subject, pred, kana, kpred])
    assert_equal 2, obj.predicate_for(subject).id
    assert_nil obj.predicate_for(kana)
  end
end
