require 'minitest/autorun'
require_relative '../../../app/services/search/arabic_normalizer'
require_relative '../../../app/services/search/quran_index'

class QuranIndexTest < Minitest::Test
  def build
    entries = [
      Search::QuranIndex::Entry.new(1, '112:1', 1, { 'a' => 'قل هو الله احد' }),
      Search::QuranIndex::Entry.new(2, '112:2', 2, { 'a' => 'الله الصمد' }),
      Search::QuranIndex::Entry.new(3, '112:3', 3, { 'a' => 'لم يلد ولم يولد' }),
      Search::QuranIndex::Entry.new(4, '112:4', 4, { 'a' => 'ولم يكن له كفوا احد' })
    ]
    Search::QuranIndex.new(entries, columns: ['a'])
  end

  def test_single_ayah_match
    assert_equal [2], build.verse_ids('الصمد')
  end

  def test_query_spanning_two_ayahs
    assert_equal [2, 3], build.verse_ids('الله الصمد لم يلد ولم يولد')
  end

  def test_partial_boundary_ayah_is_included
    assert_equal [1, 2], build.verse_ids('احد الله الصمد')
  end

  def test_non_contiguous_text_does_not_match
    assert_equal [], build.verse_ids('كفوا الصمد')
  end

  def test_blank_query
    assert_equal [], build.verse_ids('   ')
  end

  def test_results_are_ordered_by_verse_index
    assert_equal [1, 2, 3], build.verse_ids('الله احد الله الصمد لم يلد')
  end
end
