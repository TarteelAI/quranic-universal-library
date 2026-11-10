# frozen_string_literal: true

module Catalog
  # A resource type with its copy from Catalog::Taxonomy.
  class TypeResource < ApplicationResource
    typelize key: :string, label: :string, title: :string, summary: :string, description: :string
    attributes :key, :label, :title, :summary, :description

    one :category, resource: CategoryResource
  end
end
