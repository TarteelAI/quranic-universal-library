# frozen_string_literal: true

module Account
  # The filter of the profile page's open tab: its query parameter, the chosen value and the
  # values to choose from.
  class FilterResource < ApplicationResource
    typelize param: :string, value: [:string, { nullable: true }]
    attributes :param, :value
    many :options, resource: Catalog::OptionResource
  end
end
