# frozen_string_literal: true

module Content
  # A docs page (Content::DocPage): a markdown page or a tag page, its body as segments, the
  # contents list and its place in config/docs.yml.
  class DocResource < ApplicationResource
    typelize key: :string, kind: [:string, { enum: %w[page tag] }], title: :string,
             description: [:string, { nullable: true }]
    attributes :key, :kind, :title, :description

    many :segments, resource: DocSegmentResource
    many :contents, resource: DocHeadingResource
    one :position, resource: DocPositionResource
  end
end
