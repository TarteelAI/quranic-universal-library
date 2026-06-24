require 'minitest/autorun'
require_relative '../../../app/services/search/arabic_normalizer'
require_relative '../../../app/services/search/pattern'

class PatternTest < Minitest::Test
  def like(query, exact: false)
    Search::Pattern.new(query, exact: exact).like
  end

  def test_plain_phrase_is_wrapped_for_substring
    assert_equal "%abc%", like("abc", exact: true)
  end

  def test_star_becomes_wildcard
    assert_equal "%a%b%", like("a*b", exact: true)
  end

  def test_end_anchor_drops_trailing_wildcard
    assert_equal "%ab", like("ab$", exact: true)
  end

  def test_start_anchor_drops_leading_wildcard
    assert_equal "ab%", like("^ab", exact: true)
  end

  def test_both_anchors
    assert_equal "ab", like("^ab$", exact: true)
  end

  def test_anchor_with_wildcard
    assert_equal "a%b", like("^a*b$", exact: true)
  end

  def test_escapes_like_metacharacters
    assert_equal "%50\\%%", like("50%", exact: true)
  end

  def test_normalized_phrase_with_wildcard
    assert_equal "%من%الله%", like("مِن * ٱللَّهِ", exact: false)
  end

  def test_word_gap_is_not_a_like_pattern
    pattern = Search::Pattern.new("مِن {2} ٱللَّهِ", exact: false)
    assert pattern.word_gap?
    refute Search::Pattern.new("مِن * ٱللَّهِ", exact: false).word_gap?
  end

  def test_exact_word_gap_matches_only_that_count
    regexp = Search::Pattern.new("مِن {2} ٱللَّهِ", exact: false).match_regexp
    assert regexp.match?(Search::ArabicNormalizer.normalize("مِن دُونِ رَبِّهِ ٱللَّهِ"))
    refute regexp.match?(Search::ArabicNormalizer.normalize("مِن دُونِ ٱللَّهِ"))
    refute regexp.match?(Search::ArabicNormalizer.normalize("مِن دُونِ رَبِّهِ عِندَ ٱللَّهِ"))
  end

  def test_more_than_word_gap
    regexp = Search::Pattern.new("من {>2} الله", exact: false).match_regexp
    assert regexp.match?(Search::ArabicNormalizer.normalize("من دون ربه عند الله"))
    refute regexp.match?(Search::ArabicNormalizer.normalize("من دون ربه الله"))
  end

  def test_fewer_than_word_gap
    regexp = Search::Pattern.new("من {<2} الله", exact: false).match_regexp
    assert regexp.match?(Search::ArabicNormalizer.normalize("من دون الله"))
    refute regexp.match?(Search::ArabicNormalizer.normalize("من دون ربه الله"))
  end

  def test_word_gap_accepts_trailing_star
    assert Search::Pattern.new("من {2}* الله", exact: false).word_gap?
  end

  def test_blank_when_only_operators
    assert Search::Pattern.new("^$", exact: true).blank?
    assert Search::Pattern.new("*", exact: true).blank?
    refute Search::Pattern.new("ab", exact: true).blank?
  end

  def test_match_regexp_honors_start_anchor
    regexp = Search::Pattern.new("^قل", exact: false).match_regexp
    assert regexp.match?(Search::ArabicNormalizer.normalize("قُلۡ هُوَ"))
    refute regexp.match?(Search::ArabicNormalizer.normalize("وَقُلۡ"))
  end

  def test_match_regexp_honors_end_anchor
    regexp = Search::Pattern.new("صادقين$", exact: false).match_regexp
    assert regexp.match?(Search::ArabicNormalizer.normalize("كُنتُمۡ صَادِقِينَ"))
    refute regexp.match?(Search::ArabicNormalizer.normalize("صَادِقِينَ كَذَا"))
  end

  def test_match_regexp_wildcard_spans_words
    regexp = Search::Pattern.new("من*الله", exact: false).match_regexp
    assert regexp.match?(Search::ArabicNormalizer.normalize("مِّن دُونِ ٱللَّهِ"))
  end

  def test_highlight_regexp_ignores_edge_wildcards
    regexp = Search::Pattern.new("*الله", exact: false).highlight_regexp
    match = regexp.match(Search::ArabicNormalizer.normalize("بسم الله"))
    assert_equal Search::ArabicNormalizer.normalize("الله"), match[0]
  end
end
