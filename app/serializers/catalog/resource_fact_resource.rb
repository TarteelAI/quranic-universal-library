# frozen_string_literal: true

module Catalog
  # A labelled fact on the Data tab of a resource detail page.
  class ResourceFactResource < ApplicationResource
    typelize label: :string, value: :string
    attributes :label, :value
  end
end
