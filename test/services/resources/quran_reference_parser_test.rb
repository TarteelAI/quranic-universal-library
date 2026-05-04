require_relative '../../test_helper'
require_relative '../../../app/services/resources/quran_reference_parser'
require 'yaml'

class QuranReferenceParserTest < Minitest::Test
  include ResourceSearchTestSupport

  def setup
    install_quran_fixture
  end

  def test_parses_numeric_quran_reference
    result = Resources::QuranReferenceParser.new('2:255').parse

    assert result
    assert_equal '2:255', result.verse_key
    assert_equal 2, result.chapter_id
    assert_equal 255, result.verse_number
    assert_equal 'Al-Baqarah', result.chapter.name_simple
    assert_equal '', result.remaining_query
  end

  def test_parses_named_quran_reference_and_keeps_remaining_query
    result = Resources::QuranReferenceParser.new('translation al-baqarah 255').parse

    assert result
    assert_equal '2:255', result.verse_key
    assert_equal 'translation', result.remaining_query
  end

  def test_parses_curated_surah_aliases_with_ayah_numbers
    %w[fatihah fatiha fateha fateh].each do |query|
      result = Resources::QuranReferenceParser.new("#{query} 1").parse

      assert result, "expected #{query.inspect} to parse"
      assert_equal '1:1', result.verse_key
      assert_equal 1, result.chapter_id
      assert_equal 'Al-Fatihah', result.chapter.name_simple
    end
  end

  def test_parses_surah_name_with_optional_keywords
    result = Resources::QuranReferenceParser.new('surah fatihah ayah 1').parse

    assert result
    assert_equal '1:1', result.verse_key
    assert_equal '', result.remaining_query
  end

  def test_parses_arabic_alias_when_present_in_catalog
    chapter = FakeChapterRecord.new(chapter_number: 3, name_simple: 'Ali Imran', name_complex: 'Aal Imran')
    Chapter.records << chapter
    Verse.records << FakeVerseRecord.new(chapter_id: 3, verse_number: 1, verse_key: '3:1', chapter: chapter)

    result = Resources::QuranReferenceParser.new('آل عمران 1').parse

    assert result
    assert_equal '3:1', result.verse_key
    assert_equal 3, result.chapter_id
  end

  def test_rejects_false_positive_fuzzy_matches
    %w[faith father].each do |query|
      result = Resources::QuranReferenceParser.new("#{query} 1").parse
      assert_nil result, "expected #{query.inspect} not to parse"
    end
  end

  def test_rejects_ambiguous_fuzzy_match
    alternate = FakeChapterRecord.new(chapter_number: 99, name_simple: 'Al-Fathaq', name_complex: 'Al Fathaq')
    Chapter.records << alternate
    Verse.records << FakeVerseRecord.new(chapter_id: 99, verse_number: 1, verse_key: '99:1', chapter: alternate)

    result = Resources::QuranReferenceParser.new('fatha 1').parse

    assert_nil result
  end

  def test_returns_numeric_reference_even_without_matching_verse_record
    Verse.records = []

    result = Resources::QuranReferenceParser.new('surah 2 ayah 255').parse

    assert result
    assert_equal '2:255', result.verse_key
    assert_equal 2, result.chapter_id
    assert_equal 255, result.verse_number
    assert_equal 'Al-Baqarah', result.chapter.name_simple
  end

  def test_alias_catalog_covers_all_surahs
    path = File.expand_path('../../../config/resources/surah_name_aliases.yml', __dir__)
    aliases = YAML.safe_load(File.read(path), permitted_classes: [], aliases: false)

    assert_equal (1..114).to_a, aliases.keys.map(&:to_i).sort
    assert_includes aliases[48], 'Fateh'
    assert_includes aliases[112], 'قل هو الله احد'
    assert_includes aliases[114], 'Mankind'
  end
end
