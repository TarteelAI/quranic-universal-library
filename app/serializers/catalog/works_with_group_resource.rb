# frozen_string_literal: true

module Catalog
  # One relation group of "Works with" on a resource detail page (Catalog::ResourcePage::Group).
  class WorksWithGroupResource < ApplicationResource
    typelize key: [:string, { enum: ResourcePage::GROUPS.pluck(:key) }], label: :string
    attributes :key, :label

    many :links, resource: WorksWithLinkResource
  end
end
