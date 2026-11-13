# frozen_string_literal: true

module Requests
  # Props of the requests page (Requests::RequestsController#index): one page of visible
  # requests (Requests::ListQuery), the sort, the page and the number of requests in all.
  class RequestsIndexResource < ApplicationResource
    typelize sort: [:string, { enum: ListQuery::SORTS }], page: :number, pages: :number, total: :number
    attributes :sort, :page, :pages, :total
    many :requests, resource: ListItemResource
  end
end
