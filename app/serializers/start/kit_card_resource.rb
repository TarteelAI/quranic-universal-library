# frozen_string_literal: true

module Start
  # A starter kit's card (a Kits::Listed), on the kits index and the home page: what it is for,
  # its link and the name and category of each published resource in it.
  class KitCardResource < ApplicationResource
    typelize key: :string, title: :string, tag: :string, blurb: :string, path: :string
    attribute(:key) { |listed| listed.kit.key }
    attribute(:title) { |listed| listed.kit.title }
    attribute(:tag) { |listed| listed.kit.tag }
    attribute(:blurb) { |listed| listed.kit.blurb }
    attribute(:path) { |listed| Rails.application.routes.url_helpers.start_kit_path(listed.kit.key) }
    many :resources, source: proc { entries.map(&:resource) }, resource: KitCardItemResource
  end
end
