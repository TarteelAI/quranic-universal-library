# frozen_string_literal: true

module NameTranslateable
  extend ActiveSupport::Concern

  included do
    has_many :translated_names, as: :resource

    # For eager loading
    has_one :translated_name, as: :resource
  end

  def add_name(name:, language_id:)
    translated = translated_names.where(language_id: language_id).first_or_initialize
    translated.name = name
    translated.save
  end
end