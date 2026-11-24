require 'minitest/autorun'
require 'nokogiri'
require 'active_support/core_ext/object/blank'
require_relative '../../../app/services/search/arabic_normalizer'
require_relative '../../../app/services/quran_quote/word_index'
require_relative '../../../app/services/quran_quote/tagger'

class QuranQuoteTaggerTest < Minitest::Test
  # Al-Ikhlas (verse ids 1-4) and the first ayah of Al-Falaq (5) and An-Nas (6), each word as
  # [location, verse_id, [spellings]]
  WORDS = [
    ['112:1:1', 1, ['قُلۡ', 'قل']], ['112:1:2', 1, ['هُوَ', 'هو']], ['112:1:3', 1, ['ٱللَّهُ', 'الله']], ['112:1:4', 1, ['أَحَدٌ', 'احد']],
    ['112:2:1', 2, ['ٱللَّهُ', 'الله']], ['112:2:2', 2, ['ٱلصَّمَدُ', 'الصمد']],
    ['112:3:1', 3, ['لَمۡ', 'لم']], ['112:3:2', 3, ['يَلِدۡ', 'يلد']], ['112:3:3', 3, ['وَلَمۡ', 'ولم']], ['112:3:4', 3, ['يُولَدۡ', 'يولد']],
    ['112:4:1', 4, ['وَلَمۡ', 'ولم']], ['112:4:2', 4, ['يَكُن', 'يكن']], ['112:4:3', 4, ['لَّهُۥ', 'له']], ['112:4:4', 4, ['كُفُوًا', 'كفوا']], ['112:4:5', 4, ['أَحَدُۢ', 'احد']],
    ['113:1:1', 5, ['قُلۡ', 'قل']], ['113:1:2', 5, ['أَعُوذُ', 'اعوذ']], ['113:1:3', 5, ['بِرَبِّ', 'برب']], ['113:1:4', 5, ['ٱلۡفَلَقِ', 'الفلق']],
    ['114:1:1', 6, ['قُلۡ', 'قل']], ['114:1:2', 6, ['أَعُوذُ', 'اعوذ']], ['114:1:3', 6, ['بِرَبِّ', 'برب']], ['114:1:4', 6, ['ٱلنَّاسِ', 'الناس']]
  ].freeze

  def index
    @index ||= QuranQuote::WordIndex.new(WORDS)
  end

  def tag(html, verse_ids: nil)
    fragment = Nokogiri::HTML::DocumentFragment.parse(html)
    QuranQuote::Tagger.new(verse_ids: verse_ids, index: index).tag(fragment)
    fragment.to_html
  end

  def test_tags_a_quote_across_ayahs_with_its_first_and_last_word
    html = tag('<p>He said: ﴿اللَّهُ الصَّمَدُ (٢) لَمْ يَلِدْ﴾ and more</p>')

    assert_equal '<p>He said: <quran-text data-from="112:2:1" data-to="112:3:2">﴿اللَّهُ الصَّمَدُ (٢) لَمْ يَلِدْ﴾</quran-text> and more</p>', html
  end

  def test_tafsir_ayahs_pick_the_place_when_words_repeat
    # "قل" starts both 112:1 and 113:1
    assert_includes tag('<p>﴿قل﴾</p>', verse_ids: 5..5), 'data-from="113:1:1"'
    assert_includes tag('<p>﴿قل﴾</p>', verse_ids: 1..4), 'data-from="112:1:1"'
  end

  def test_repeated_bracketed_quote_is_tagged_without_location
    # 113:1 and 114:1 both start with these words
    assert_equal '<p>قال <quran-text>﴿قل أعوذ برب﴾</quran-text></p>', tag('<p>قال ﴿قل أعوذ برب﴾</p>')
    assert_includes tag('<p>﴿قل أعوذ برب﴾</p>', verse_ids: 6..6), 'data-from="114:1:1" data-to="114:1:3"'
  end

  def test_one_bracketed_word_needs_the_tafsir_ayahs
    assert_equal '<p>﴿الصمد﴾</p>', tag('<p>﴿الصمد﴾</p>', verse_ids: 5..6)
    assert_includes tag('<p>﴿الصمد﴾</p>', verse_ids: 2..2), 'data-from="112:2:2"'
  end

  def test_plain_text_needs_more_words_than_a_bracketed_quote
    assert_equal '<p>الله الصمد</p>', tag('<p>الله الصمد</p>')
    assert_includes tag('<p>قل هو الله احد</p>'), 'data-from="112:1:1" data-to="112:1:4"'
    assert_includes tag('<p>الله الصمد لم</p>', verse_ids: 2..3), 'data-from="112:2:1"'
  end

  def test_plain_text_in_several_places_is_left_alone
    # "قل أعوذ برب" starts both 113:1 and 114:1
    assert_equal '<p>قل أعوذ برب</p>', tag('<p>قل أعوذ برب</p>')
  end

  def test_qpc_hafs_span_holding_a_quote_becomes_the_tag
    html = tag('<p>Allah says <span class="qpc-hafs brown">﴿قل هو الله احد﴾</span>.</p>')

    assert_equal '<p>Allah says <quran-text class="brown" data-from="112:1:1" data-to="112:1:4">﴿قل هو الله احد﴾</quran-text>.</p>', html
  end

  def test_paragraph_holding_only_a_quote_is_replaced_by_it
    html = tag('<p>Allah says:</p><p class="ar qpc-hafs red" lang="ar">﴿قل هو الله احد﴾</p><p>meaning...</p>')

    assert_equal '<p>Allah says:</p><quran-text data-from="112:1:1" data-to="112:1:4" class="red">﴿قل هو الله احد﴾</quran-text><p>meaning...</p>', html
  end

  def test_paragraph_with_more_than_the_quote_is_kept
    html = tag('<p class="ar">قال: ﴿قل هو الله احد﴾</p>')

    assert html.start_with?('<p class="ar">قال: <quran-text')
  end

  def test_qpc_hafs_is_dropped_from_other_arabic
    html = tag('<p class="ar qpc-hafs">مَنْ صَلَّى صَلَاةً، فَهِيَ خِدَاجٌ</p><span class="qpc-hafs">نص</span>')

    assert_equal '<p class="ar">مَنْ صَلَّى صَلَاةً، فَهِيَ خِدَاجٌ</p><span>نص</span>', html
  end

  def test_existing_tags_are_kept
    html = '<p>قال <quran-text data-from="112:1:1" data-to="112:1:4" data-script="dk">قل هو الله احد</quran-text></p>'

    assert_equal html, tag(html)
  end

  def test_locate_selected_text
    result = QuranQuote::Tagger.new(index: index).locate('ٱللَّهُ ٱلصَّمَدُ')

    assert_equal ['112:2:1', '112:2:2', 2, 2], [result.from, result.to, result.words, result.total]
  end

  def test_locate_reports_partial_match
    result = QuranQuote::Tagger.new(index: index).locate('الله الصمد كلام')

    assert_equal [2, 3], [result.words, result.total]
  end

  def test_locate_text_not_in_the_quran
    refute QuranQuote::Tagger.new(index: index).locate('كلام آخر').found?
  end
end
