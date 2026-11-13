# frozen_string_literal: true

module Content
  # A page in the docs navigation (Content::DocsNavigation): 0 for a page of a category, 1 for a
  # page under another page (a tutorial under Tutorials).
  class DocNavPageResource < ApplicationResource
    typelize key: :string, title: :string, depth: :number
    attributes :key, :title, :depth
  end
end
