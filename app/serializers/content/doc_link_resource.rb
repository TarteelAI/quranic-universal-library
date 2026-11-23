# frozen_string_literal: true

module Content
  # A docs page or category named in config/docs.yml: its key under /docs and its title there.
  class DocLinkResource < ApplicationResource
    typelize key: :string, title: :string
    attributes :key, :title
  end
end
