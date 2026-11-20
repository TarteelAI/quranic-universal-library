# frozen_string_literal: true

module Site
  # One resource of a SampleCardsResource: its label (a script family, a language), name, link
  # and card preview.
  class SampleCardResource < ApplicationResource
    typelize label: :string, name: :string, to_param: :string,
             preview: 'Previews::CardScriptResource | Previews::CardTextResource'
    attributes :label, :preview
    attribute(:name) { |card| card[:resource].catalog_name }
    attribute(:to_param) { |card| card[:resource].to_param }
  end
end
