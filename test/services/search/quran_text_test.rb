require 'minitest/autorun'
require_relative '../../../app/services/search/arabic_normalizer'
require_relative '../../../app/services/search/pattern'

class FakeRelation
  attr_reader :args, :ordered_by

  def initialize(*args)
    @args = args
  end

  def clause
    @args[0]
  end

  def binds
    @args[1]
  end

  def conditions
    @args[0]
  end

  def order(column)
    @ordered_by = column
    self
  end
end

class Verse
  def self.sanitize_sql_like(string)
    string.gsub(/[\\%_]/) { |char| "\\#{char}" }
  end

  def self.where(*args)
    FakeRelation.new(*args)
  end

  def initialize(attrs)
    @attrs = attrs
  end

  def read_attribute(column)
    @attrs[column]
  end
end

require_relative '../../../app/services/search/quran_text'

class QuranTextTest < Minitest::Test
  N = Search::ArabicNormalizer

  def test_matched_columns_reports_only_matching_scripts
    verse = Verse.new(
      "text_qpc_hafs" => "فَإِلَٰهُكُمۡ",
      "text_indopak" => "بِسۡمِ"
    )
    search = Search::QuranText.new(query: "الهكم", exact: false)

    matched = search.matched_columns(verse)
    assert_includes matched, "text_qpc_hafs"
    refute_includes matched, "text_indopak"
  end

  def test_relation_builds_normalized_or_clause_with_sanitized_param
    search = Search::QuranText.new(query: "الهكم", exact: false)
    relation = search.relation

    expected_clause = Search::QuranText::SEARCH_COLUMNS
                        .map { |column| "#{N.sql_normalize(column)} ILIKE :q" }
                        .join(' OR ')
    assert_equal expected_clause, relation.clause
    assert_equal "%الهكم%", relation.binds[:q]
  end

  def test_relation_uses_raw_columns_when_exact
    search = Search::QuranText.new(query: "الله", exact: true)
    relation = search.relation

    expected_clause = Search::QuranText::SEARCH_COLUMNS
                        .map { |column| "#{column} ILIKE :q" }
                        .join(' OR ')
    assert_equal expected_clause, relation.clause
    assert_equal "%الله%", relation.binds[:q]
  end

  def test_relation_escapes_like_wildcards_in_term
    search = Search::QuranText.new(query: "50%", exact: true)
    relation = search.relation
    assert_equal "%50\\%%", relation.binds[:q]
  end

  def test_relation_supports_wildcard_pattern
    search = Search::QuranText.new(query: "من*الله", exact: true)
    assert_equal "%من%الله%", search.relation.binds[:q]
  end

  def test_relation_supports_end_anchor
    search = Search::QuranText.new(query: "صادقين$", exact: true)
    assert_equal "%صادقين", search.relation.binds[:q]
  end

  def test_relation_uses_regexp_operator_for_word_gap
    search = Search::QuranText.new(query: "من {2} الله", exact: true)
    relation = search.relation

    assert_includes relation.clause, "~*"
    refute_includes relation.clause, "ILIKE"
    assert_equal "من\\s+(?:\\S+\\s+){2}الله", relation.binds[:q]
  end

  def test_ordered_sorts_by_verse_index
    search = Search::QuranText.new(query: "الله", exact: true)
    assert_equal :verse_index, search.ordered.ordered_by
  end

  def test_tajweed_columns_are_excluded
    refute_includes Search::QuranText::SEARCH_COLUMNS, "text_qpc_hafs_tajweed"
    refute_includes Search::QuranText::SEARCH_COLUMNS, "text_uthmani_tajweed"
  end

  def test_across_mode_uses_index_verse_ids
    fake_index = Object.new
    def fake_index.verse_ids(_query) = [2, 3]

    search = Search::QuranText.new(query: "الله الصمد لم يلد", across: true, index: fake_index)
    assert search.across?
    assert_equal({ id: [2, 3] }, search.relation.conditions)
  end

  def test_across_mode_has_no_matched_columns
    fake_index = Object.new
    def fake_index.verse_ids(_query) = [2]

    search = Search::QuranText.new(query: "الله", across: true, index: fake_index)
    assert_equal [], search.matched_columns(Object.new)
  end

  def test_detects_ayah_key_across_separators
    %w[1:2 1,2 1-2].each do |query|
      assert_equal "1:2", Search::QuranText.new(query: query).ayah_key, "expected #{query.inspect} to parse"
    end

    assert_equal "1:2", Search::QuranText.new(query: "1 2").ayah_key
    assert_equal "1:2", Search::QuranText.new(query: "1 : 2").ayah_key
  end

  def test_strips_leading_zeros_in_ayah_key
    assert_equal "1:2", Search::QuranText.new(query: "001:02").ayah_key
  end

  def test_text_query_is_not_an_ayah_key
    assert_nil Search::QuranText.new(query: "الله").ayah_key
    assert_nil Search::QuranText.new(query: "12").ayah_key
    assert_nil Search::QuranText.new(query: "1:2:3").ayah_key
  end

  def test_relation_looks_up_verse_key_for_ayah_key_query
    search = Search::QuranText.new(query: "1-2")
    assert_equal({ verse_key: "1:2" }, search.relation.conditions)
  end
end
