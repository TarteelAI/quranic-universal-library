require 'minitest/autorun'
require_relative '../../../app/services/search/arabic_normalizer'
require_relative '../../../app/services/search/pattern'
require_relative '../../../app/services/search/highlighter'

class HighlighterTest < Minitest::Test
  def test_exact_wraps_single_occurrence
    result = Search::Highlighter.highlight("بسم الله", "الله", exact: true)
    assert_equal "بسم <mark>الله</mark>", result
  end

  def test_exact_wraps_all_occurrences
    result = Search::Highlighter.highlight("نا نا نا", "نا", exact: true)
    assert_equal "<mark>نا</mark> <mark>نا</mark> <mark>نا</mark>", result
  end

  def test_exact_no_match_returns_escaped_text
    result = Search::Highlighter.highlight("بسم الله", "xyz", exact: true)
    assert_equal "بسم الله", result
  end

  def test_normalized_match_keeps_interior_marks_but_trims_trailing_mark
    text = "فَإِلَٰهُكُمۡ"
    result = Search::Highlighter.highlight(text, "الهكم", exact: false)
    assert_equal "فَ<mark>إِلَٰهُكُم</mark>ۡ", result
  end

  def test_normalized_match_does_not_leak_past_matched_letters
    text = "فَٱللَّهُ"
    result = Search::Highlighter.highlight(text, "فال", exact: false)
    assert_equal "<mark>فَٱل</mark>لَّهُ", result
  end

  def test_normalized_no_match_returns_escaped_text
    text = "فَإِلَٰهُكُمۡ"
    result = Search::Highlighter.highlight(text, "بسم", exact: false)
    assert_equal text, result
  end

  def test_escapes_html_in_text
    result = Search::Highlighter.highlight("<b>x</b>", "y", exact: true)
    assert_equal "&lt;b&gt;x&lt;/b&gt;", result
  end

  def test_escapes_html_within_match
    result = Search::Highlighter.highlight("a<b>a", "<b>", exact: true)
    assert_equal "a<mark>&lt;b&gt;</mark>a", result
  end

  def test_blank_query_returns_escaped_text
    result = Search::Highlighter.highlight("بسم الله", "", exact: false)
    assert_equal "بسم الله", result
  end

  def test_wildcard_highlights_whole_matched_span
    result = Search::Highlighter.highlight("مِّن دُونِ ٱللَّهِ", "من*الله", exact: false)
    inner = result[/<mark>(.*)<\/mark>/m, 1]
    assert_equal "من دون الله", Search::ArabicNormalizer.normalize(inner)
  end

  def test_end_anchor_query_highlights_literal
    result = Search::Highlighter.highlight("كنتم صادقين", "صادقين$", exact: false)
    assert_equal "كنتم <mark>صادقين</mark>", result
  end

  def test_contained_highlights_whole_verse_when_inside_query
    result = Search::Highlighter.highlight_contained("الله الصمد", "الله الصمد لم يلد", exact: false)
    assert_equal "<mark>الله الصمد</mark>", result
  end

  def test_contained_highlights_boundary_suffix
    result = Search::Highlighter.highlight_contained("قل هو الله احد", "احد الله الصمد", exact: false)
    assert_equal "قل هو الله <mark>احد</mark>", result
  end

  def test_contained_returns_plain_text_when_no_overlap
    result = Search::Highlighter.highlight_contained("كفوا احد", "الله الصمد", exact: false)
    assert_equal "كفوا احد", result
  end

  def test_contained_excludes_nbsp_joined_trailing_number
    verse = [0x627, 0x644, 0x644, 0x647, 0x20, 0x627, 0x644, 0x635, 0x645, 0x62F, 0x00A0, 0x662].pack('U*')
    body = [0x627, 0x644, 0x644, 0x647, 0x20, 0x627, 0x644, 0x635, 0x645, 0x62F].pack('U*')
    tail = [0x00A0, 0x662].pack('U*')

    result = Search::Highlighter.highlight_contained(verse, "الله الصمد لم يلد", exact: false)
    assert_equal "<mark>#{body}</mark>#{tail}", result
  end
end
