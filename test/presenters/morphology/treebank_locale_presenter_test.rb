require_relative '../../test_helper'
require_relative '../../../app/presenters/morphology/treebank_locale_presenter'

class TreebankLocalePresenterTest < Minitest::Test
  Presenter = Morphology::TreebankLocalePresenter

  def test_resolve_returns_supported_codes_unchanged
    %w[en ar ur ru].each { |code| assert_equal code, Presenter.resolve(code) }
  end

  def test_resolve_falls_back_to_en_for_nil
    assert_equal 'en', Presenter.resolve(nil)
  end

  def test_resolve_falls_back_to_en_for_blank
    assert_equal 'en', Presenter.resolve('')
  end

  def test_resolve_falls_back_to_en_for_unknown_code
    assert_equal 'en', Presenter.resolve('fr')
  end

  def test_resolve_is_case_sensitive
    assert_equal 'en', Presenter.resolve('AR')
  end

  def test_resolve_accepts_symbol
    assert_equal 'ar', Presenter.resolve(:ar)
  end

  def test_labels_maps_codes_to_labels_in_supported_order
    expected = { 'en' => 'English', 'ar' => 'العربية', 'ur' => 'اردو', 'ru' => 'Русский' }
    assert_equal expected.to_a, Presenter.labels.to_a
  end

  def test_direction_is_ltr_for_latin_and_cyrillic_locales
    assert_equal 'ltr', Presenter.direction('en')
    assert_equal 'ltr', Presenter.direction('ru')
  end

  def test_direction_is_rtl_for_arabic_script_locales
    assert_equal 'rtl', Presenter.direction('ar')
    assert_equal 'rtl', Presenter.direction('ur')
  end

  def test_css_class_is_locale_code_for_arabic_script_locales
    assert_equal 'ar', Presenter.css_class('ar')
    assert_equal 'ur', Presenter.css_class('ur')
  end

  def test_css_class_is_empty_for_ltr_locales
    assert_equal '', Presenter.css_class('en')
    assert_equal '', Presenter.css_class('ru')
  end

  def test_direction_rejects_unsupported_code
    assert_raises(ArgumentError) { Presenter.direction('fr') }
  end

  def test_css_class_rejects_unsupported_code
    assert_raises(ArgumentError) { Presenter.css_class('fr') }
  end
end
