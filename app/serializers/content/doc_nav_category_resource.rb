# frozen_string_literal: true

module Content
  # A category of config/docs.yml with its pages in reading order, for the docs navigation and the
  # docs index. Its key is also the key of its overview page.
  class DocNavCategoryResource < ApplicationResource
    typelize key: :string, title: :string, description: [:string, { nullable: true }],
             badge: [:string, { nullable: true }]
    attributes :key, :title, :description, :badge

    many :pages, resource: DocNavPageResource
  end
end
