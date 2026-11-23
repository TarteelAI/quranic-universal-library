require 'minitest/autorun'
require 'active_support/core_ext/object/blank'

# The action only needs params and render from ActionController::API.
module Api
  module V1
    class ApiController; end
  end
end unless defined?(Api::V1::ApiController)

require_relative '../../../../app/controllers/api/v1/unicode_controller'

class UnicodeControllerTest < Minitest::Test
  NAMES = { 0x0626 => 'ARABIC LETTER YEH WITH HAMZA ABOVE' }.freeze

  def lookup(code_point)
    controller = Api::V1::UnicodeController.new
    response = {}
    controller.define_singleton_method(:params) { { code_point: code_point } }
    controller.define_singleton_method(:render) { |json:, status: :ok| response.update(json: json, status: status) }
    # Stand in for the unicode-name gem, which the test job does not install.
    controller.define_singleton_method(:require) { |*| true }
    names = Module.new { define_singleton_method(:of) { |char| NAMES[char.ord] } }

    with_unicode_name(names) { with_rails_default_internal { controller.name } }
    response
  end

  # Rails sets this, and the old `Integer#chr` without an encoding relied on it.
  def with_rails_default_internal
    original = Encoding.default_internal
    Encoding.default_internal = Encoding::UTF_8
    yield
  ensure
    Encoding.default_internal = original
  end

  def with_unicode_name(names)
    Object.const_set(:Unicode, Module.new) unless defined?(::Unicode)
    original = ::Unicode.const_defined?(:Name, false) ? ::Unicode.const_get(:Name) : nil
    ::Unicode.send(:remove_const, :Name) if original
    ::Unicode.const_set(:Name, names)
    yield
  ensure
    ::Unicode.send(:remove_const, :Name)
    ::Unicode.const_set(:Name, original) if original
  end

  def test_html_entity_is_a_valid_decimal_character_reference
    json = lookup('0626')[:json]

    assert_equal '&#1574;', json[:html_entity]
    assert_equal '&#x626;', json[:html_entity_hex]
    assert_equal 'ARABIC LETTER YEH WITH HAMZA ABOVE', json[:name]
  end

  def test_accepts_u_plus_and_0x_prefixes
    assert_equal '0626', lookup('U+0626')[:json][:code_point]
    assert_equal '0626', lookup('u+0626')[:json][:code_point]
    assert_equal '0626', lookup('0x0626')[:json][:code_point]
  end

  # These used to parse as 0 and answer 200 for U+0000.
  def test_rejects_values_that_are_not_hex_code_points
    %w[zz 06z6 -1 1234567].each do |value|
      assert_equal :bad_request, lookup(value)[:status], value
    end
  end

  def test_rejects_code_points_outside_unicode
    assert_equal :bad_request, lookup('110000')[:status]
    assert_equal :bad_request, lookup('D800')[:status]
  end
end
