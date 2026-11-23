# frozen_string_literal: true

module Content
  # Props of a docs page (Content::DocsController#show): the page and the docs navigation.
  class DocsShowResource < ApplicationResource
    one :doc, resource: DocResource
    many :navigation, resource: DocNavCategoryResource
  end
end
