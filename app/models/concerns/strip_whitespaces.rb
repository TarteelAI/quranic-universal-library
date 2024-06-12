# frozen_string_literal: true

module StripWhitespaces
  extend ActiveSupport::Concern

  included do
    before_save :strip_fields
  end

  protected

  def strip_fields
    attributes_to_strip.each do |key|
      value = self[key]

      if value && value.respond_to?(:strip)
        clean_value = value.strip
        self[key] = clean_value if value != clean_value
      end
    end
  end

  def attributes_to_strip
    self.attributes.keys
  end
end
