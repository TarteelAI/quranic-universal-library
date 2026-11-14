# frozen_string_literal: true

module Catalog
  # The version and updated date of a resource (Catalog::ResourcePage): the export version where
  # the content row has one, and its date, else no version and the date of the newest file.
  class ResourceReleaseResource < ApplicationResource
    typelize version: [:string, { nullable: true }], updated_on: [:string, { nullable: true }]
    attribute(:version, &:version)
    attribute(:updated_on) { |page| page.updated_on&.strftime(ResourcePage::DATE_FORMAT) }
  end
end
