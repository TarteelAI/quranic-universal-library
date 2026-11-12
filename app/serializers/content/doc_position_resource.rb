# frozen_string_literal: true

module Content
  # Where a docs page sits in config/docs.yml: its category and the pages before and after it in
  # reading order. All null for a page the manifest does not list, and for a tag page.
  class DocPositionResource < ApplicationResource
    typelize category: { nullable: true }, previous: { nullable: true }, next: { nullable: true }
    one :category, resource: DocLinkResource
    one :previous, resource: DocLinkResource
    one :next, resource: DocLinkResource
  end
end
