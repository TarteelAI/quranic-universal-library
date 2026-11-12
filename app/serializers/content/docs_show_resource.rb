# frozen_string_literal: true

module Content
  # Props of a docs page (Content::DocsController#show).
  class DocsShowResource < ApplicationResource
    one :doc, resource: DocResource
  end
end
