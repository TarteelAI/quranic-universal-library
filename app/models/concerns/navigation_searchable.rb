# frozen_string_literal: true

module NavigationSearchable
  extend ActiveSupport::Concern

  included do
    has_many :navigation_search_records, as: :searchable_record
  end

  def add_navigation_search(text:)
    record = navigation_search_records.where(text: text).first_or_initialize

    record.save
  end
end