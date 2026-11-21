# frozen_string_literal: true

module Content
  # A page of the docs search index (Content::DocsSearchIndex): its key, title, category title,
  # contents list (h2 and h3 headings with their ids in the page), and its prose as plain text.
  class DocsSearchEntryResource < ApplicationResource
    typelize key: :string, title: :string, category: [:string, { nullable: true }], text: :string
    attributes :key, :title, :category, :text
    many :headings, resource: DocHeadingResource
  end
end
