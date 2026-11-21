require 'minitest/autorun'

# ApplicationPresenter includes Pagy::Backend; the per_page logic doesn't use it.
module Pagy
  module Backend; end
end unless defined?(Pagy::Backend)

require_relative '../../app/presenters/application_presenter'
require_relative '../../app/presenters/v1/api_presenter'
require_relative '../../app/presenters/v1/verse_presenter'

class PerPageTest < Minitest::Test
  def per_page(presenter_class, value)
    presenter = presenter_class.allocate
    presenter.instance_variable_set(:@params, { per_page: value })
    presenter.send(:per_page)
  end

  def test_returns_the_requested_page_size
    assert_equal 5, per_page(ApplicationPresenter, '5')
    assert_equal 20, per_page(ApplicationPresenter, '20')
    assert_equal 50, per_page(V1::VersePresenter, '50')
    assert_equal 100, per_page(V1::VersePresenter, '100')
  end

  def test_defaults_to_ten
    assert_equal 10, per_page(ApplicationPresenter, nil)
    assert_equal 10, per_page(ApplicationPresenter, '0')
    assert_equal 10, per_page(V1::VersePresenter, '')
  end

  def test_caps_the_page_size
    assert_equal ApplicationPresenter::MAX_RECORDS_PER_PAGE, per_page(ApplicationPresenter, '1000')
    assert_equal 286, per_page(V1::VersePresenter, '1000')
  end

  def test_negative_values_use_their_magnitude
    assert_equal 7, per_page(ApplicationPresenter, '-7')
  end
end
