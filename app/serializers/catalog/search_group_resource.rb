# frozen_string_literal: true

module Catalog
  # A category's run of catalog search results on one page (Catalog::SearchQuery::Group): the
  # page shows `count` results under the category's heading, out of `total` on every page.
  class SearchGroupResource < ApplicationResource
    typelize total: :number, count: :number
    attributes :total, :count
    one :category, resource: CategoryResource
  end
end
