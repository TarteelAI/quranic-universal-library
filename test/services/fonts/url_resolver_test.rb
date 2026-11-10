require_relative '../../test_helper'
require_relative '../../../app/services/fonts/url_resolver'

class FontsUrlResolverTest < Minitest::Test
  CDN = 'https://cdn.example.test'

  def resolver
    Fonts::UrlResolver.new(cdn_host: CDN)
  end

  def test_single_file_font_lists_every_format_in_browser_order
    font = resolver.from_meta({ 'font-face' => 'qpc-hafs', 'ttf' => 'UthmanicHafs_V22', 'woff2' => 'UthmanicHafs_V22' })

    assert_equal 'qpc-hafs', font.family
    refute font.per_page
    assert_equal [
      ["#{CDN}/qul/fonts/UthmanicHafs_V22.woff2", 'woff2'],
      ["#{CDN}/qul/fonts/UthmanicHafs_V22.ttf", 'truetype']
    ], font.sources.map { |source| [source.url, source.format] }
  end

  def test_otf_only_font_uses_the_opentype_format
    font = resolver.from_meta({ 'font-face' => 'digitalkhaat', 'otf' => 'dk/DigitalKhattQuranicV1' })

    assert_equal [["#{CDN}/qul/fonts/dk/DigitalKhattQuranicV1.otf", 'opentype']],
                 font.sources.map { |source| [source.url, source.format] }
  end

  def test_folder_named_after_its_format_holds_one_file_per_page
    meta = {
      'font-face' => 'p1-v2',
      'woff2' => 'quran_fonts/v2/woff2',
      'woff' => 'quran_fonts/v2/woff',
      'ttf' => 'quran_fonts/v2/ttf'
    }
    font = resolver.from_meta(meta, page: 300)

    assert font.per_page
    assert_equal 'v2-p300', font.family
    assert_equal "#{CDN}/qul/fonts/quran_fonts/v2/woff2/p300.woff2", font.url('woff2')
    assert_equal "#{CDN}/qul/fonts/quran_fonts/v2/ttf/p300.ttf", font.url('ttf')
  end

  # The V4 Tajweed font resource has no font-face key; the old font-face partial built
  # `quran_fonts/v4-tajweed/woff2.woff2` for it.
  def test_page_font_without_a_font_face_still_resolves_per_page
    meta = {
      'woff2' => 'quran_fonts/v4-tajweed/woff2',
      'woff' => 'quran_fonts/v4-tajweed/woff',
      'ttf' => 'quran_fonts/v4-tajweed/ttf',
      'preview-pattern' => 'quran_fonts/v4-tajweed/ttf/p1'
    }
    font = resolver.from_meta(meta)

    assert_equal 'v4-tajweed-p1', font.family
    assert_equal "#{CDN}/qul/fonts/quran_fonts/v4-tajweed/woff2/p1.woff2", font.url('woff2')
  end

  def test_font_resource_and_layout_code_resolve_to_the_same_page_file
    meta = { 'font-face' => 'p1-v1', 'woff2' => 'quran_fonts/v1-optimized/woff2' }

    assert_equal resolver.named('v1', page: 604).url('woff2'), resolver.from_meta(meta, page: 604).url('woff2')
    assert_equal "#{CDN}/qul/fonts/quran_fonts/v1-optimized/woff2/p604.woff2", resolver.named('v1', page: 604).url('woff2')
  end

  def test_meta_without_font_files_has_no_font
    assert_nil resolver.from_meta({ 'font-face' => 'qpc-hafs', 'ttf' => '' })
  end

  def test_layout_codes_and_their_aliases
    assert_equal "#{CDN}/qul/fonts/nastaleeq/indopak-nastaleeq-waqf-lazim.woff2", resolver.named('indopak').url('woff2')
    assert_equal 'indopak-nastaleeq', resolver.named('indopak').family
    assert_nil resolver.named('img')
    assert_nil resolver.named('svg')
    assert_nil resolver.named(nil)
  end

  def test_script_font_takes_the_first_choice_and_prefers_font_face
    assert_equal 'me_quran', resolver.for_script({ 'font' => 'me-quran or qpc-hafs' }).family
    assert_equal 'qpc-warsh', resolver.for_script({ 'font-face' => 'qpc-warsh', 'font' => 'v2' }).family
    assert_equal 'v2-p5', resolver.for_script({ 'font' => 'v2' }, page: 5).family
    assert_nil resolver.for_script({ 'text-type' => 'qa_black_image_url' })
  end

  def test_meta_keeps_only_path_characters_because_it_ends_up_in_css
    font = resolver.from_meta({ 'font-face' => "x'}</style><b>", 'woff2' => "a b/c');}<x" })

    assert_equal 'x/styleb', font.family
    assert_equal "#{CDN}/qul/fonts/ab/cx.woff2", font.url('woff2')
  end

  def test_page_must_be_a_positive_integer
    assert_raises(ArgumentError) { resolver.named('v2', page: 0) }
    assert_raises(ArgumentError) { resolver.named('v2', page: '3') }
  end
end
