# frozen_string_literal: true

module Content
  # Props of the docs index (Content::DocsController#index): the docs navigation.
  class DocsIndexResource < ApplicationResource
    many :navigation, resource: DocNavCategoryResource
  end
end
