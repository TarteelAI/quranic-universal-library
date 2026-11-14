# frozen_string_literal: true

module Start
  # One item of a kit page (a Kits::Entry over catalog search rows): what it is for, why it was
  # picked, its resource as a catalog card and the alternative to swap it for, if published.
  class KitItemResource < ApplicationResource
    typelize need: :string, why: :string
    attribute(:need) { |entry| entry.item.need }
    attribute(:why) { |entry| entry.item.why }
    one :resource, resource: Catalog::SearchResultResource

    typelize alternative: { nullable: true }
    one :alternative, source: proc { alternative&.resource }, resource: Catalog::ResourceRefResource
  end
end
