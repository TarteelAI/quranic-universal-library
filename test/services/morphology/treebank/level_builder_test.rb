require_relative '../../../test_helper'
require_relative '../../../../app/services/morphology/treebank/level_builder'

class LevelBuilderTest < Minitest::Test
  def tok(position:, span_start: nil, span_end: nil, constituent_label: nil, constituent_text: nil,
          is_constituent: 0, rel_label: 'subj', ref_position: nil,
          dependent_is_phrase: false, head_is_phrase: false)
    ref_position ||= position
    {
      position: position,
      is_constituent: is_constituent,
      span_start: span_start,
      span_end: span_end,
      constituent_label: constituent_label,
      constituent_text: constituent_text,
      rel_label: rel_label,
      ref_position: ref_position,
      dependent_is_phrase: dependent_is_phrase,
      head_is_phrase: head_is_phrase
    }
  end

  def sentence3_tokens
    [
      tok(position: 0, rel_label: 'obj',    ref_position: 1),
      tok(position: 1, is_constituent: -1, span_start: 0, span_end: 2,
          constituent_label: 'VS', constituent_text: 'إِيَّاكَ نَعْبُدُ (نحْنُ)',
          rel_label: 'root', ref_position: 1),
      tok(position: 2, rel_label: 'subj',   ref_position: 1),
      tok(position: 3, rel_label: 'nonrel', ref_position: 3),
      tok(position: 4, rel_label: 'obj',    ref_position: 5),
      tok(position: 5, is_constituent: 1, span_start: 4, span_end: 6,
          constituent_label: 'VS', constituent_text: 'إِيَّاكَ نَسْتَعِينُ (نحْنُ)',
          rel_label: 'conj', ref_position: 1,
          dependent_is_phrase: true, head_is_phrase: true),
      tok(position: 6, rel_label: 'subj', ref_position: 5)
    ]
  end

  def test_sentence3_two_flat_phrase_nodes
    result = Morphology::Treebank::LevelBuilder.new(sentence3_tokens).build

    assert_equal 2, result[:phrase_nodes].size

    n0 = result[:phrase_nodes][0]
    assert_equal [0, 2], n0[:span]
    assert_equal 'VS', n0[:label]
    assert_equal 'إِيَّاكَ نَعْبُدُ (نحْنُ)', n0[:text]
    assert_in_delta 1.0, n0[:centroid]
    assert_equal 1, n0[:level]
    assert_equal 1, n0[:head_position]

    n1 = result[:phrase_nodes][1]
    assert_equal [4, 6], n1[:span]
    assert_equal 'VS', n1[:label]
    assert_in_delta 5.0, n1[:centroid]
    assert_equal 1, n1[:level]
    assert_equal 5, n1[:head_position]
  end

  def test_sentence3_max_level
    result = Morphology::Treebank::LevelBuilder.new(sentence3_tokens).build
    assert_equal 1, result[:max_level]
  end

  def test_sentence3_top_positions
    result = Morphology::Treebank::LevelBuilder.new(sentence3_tokens).build
    top = result[:top_positions]

    assert_includes top, 3
    assert_includes top, 1.0
    assert_includes top, 5.0

    integer_top = top.select { |v| v.is_a?(Integer) }
    assert_equal [3], integer_top,
      "only uncovered token position 3 should appear as an integer in top_positions"
  end

  def test_nested_spans
    tokens = [
      tok(position: 0, rel_label: 'obj', ref_position: 2),
      tok(position: 1, is_constituent: 1, span_start: 1, span_end: 2,
          constituent_label: 'PP', constituent_text: 'a b',
          rel_label: 'mod', ref_position: 2),
      tok(position: 2, is_constituent: -1, span_start: 0, span_end: 4,
          constituent_label: 'VS', constituent_text: 'a b c d e',
          rel_label: 'root', ref_position: 2),
      tok(position: 3, rel_label: 'subj', ref_position: 2),
      tok(position: 4, rel_label: 'adj', ref_position: 2)
    ]

    result = Morphology::Treebank::LevelBuilder.new(tokens).build
    nodes = result[:phrase_nodes]

    pp_node = nodes.find { |n| n[:label] == 'PP' }
    vs_node = nodes.find { |n| n[:label] == 'VS' }

    assert pp_node, 'PP phrase node missing'
    assert vs_node, 'VS phrase node missing'
    assert_equal 1, pp_node[:level]
    assert_equal 2, vs_node[:level]
    assert_equal 2, result[:max_level]
  end

  def test_duplicate_span_produces_one_phrase_node
    tokens = [
      tok(position: 0, rel_label: 'obj', ref_position: 1),
      tok(position: 1, is_constituent: -1, span_start: 0, span_end: 2,
          constituent_label: 'VS', constituent_text: 'a b c',
          rel_label: 'root', ref_position: 1),
      tok(position: 2, is_constituent: 1, span_start: 0, span_end: 2,
          constituent_label: 'VS', constituent_text: 'a b c',
          rel_label: 'subj', ref_position: 1)
    ]

    result = Morphology::Treebank::LevelBuilder.new(tokens).build

    assert_equal 1, result[:phrase_nodes].size, "duplicate span must produce exactly one phrase node"

    n = result[:phrase_nodes][0]
    assert_equal [0, 2], n[:span]
    assert_equal 'VS', n[:label]
    assert_equal 1, n[:level]
    assert_equal 1, n[:head_position], "head_position must come from the first token carrying the span"
    assert_equal 1, result[:max_level]
  end

  def test_no_spans
    tokens = [
      tok(position: 0),
      tok(position: 1),
      tok(position: 2)
    ]

    result = Morphology::Treebank::LevelBuilder.new(tokens).build

    assert_equal [], result[:phrase_nodes]
    assert_equal 0, result[:max_level]
    assert_equal [0, 1, 2], result[:top_positions].sort
  end
end
