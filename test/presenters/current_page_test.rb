require 'minitest/autorun'

# ApplicationPresenter includes Pagy::Backend; current_page doesn't use it.
module Pagy
  module Backend; end
end unless defined?(Pagy::Backend)

require_relative '../../app/presenters/application_presenter'

class CurrentPageTest < Minitest::Test
  def current_page(value)
    presenter = ApplicationPresenter.allocate
    presenter.instance_variable_set(:@params, { page: value })
    presenter.send(:current_page)
  end

  def test_returns_the_requested_page
    assert_equal 1, current_page('1')
    assert_equal 3, current_page('3')
  end

  def test_falls_back_to_the_first_page
    assert_equal 1, current_page(nil)
    assert_equal 1, current_page('')
    assert_equal 1, current_page('0')
    assert_equal 1, current_page('abc')
  end

  # Pagy rejects a page below 1 with Pagy::VariableError, which the API
  # controllers don't rescue, so a negative page used to answer with a 500.
  def test_negative_page_falls_back_to_the_first_page
    assert_equal 1, current_page('-1')
    assert_equal 1, current_page('-3')
  end
end
