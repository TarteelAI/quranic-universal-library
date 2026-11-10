# frozen_string_literal: true

module Previews
  # The language code and direction of a preview's text (Previews::Locale).
  class LocaleResource < ApplicationResource
    typelize code: :string, direction: [:string, { enum: %w[ltr rtl] }]
    attributes :code, :direction
  end
end
