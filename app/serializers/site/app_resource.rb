# frozen_string_literal: true

module Site
  # A published app of the apps directory (App). Its platforms are labels. Never the contact.
  class AppResource < ApplicationResource
    typelize id: :string, name: :string, url: :string, kind: :string, description: :string, featured: :boolean,
             icon_url: [:string, { nullable: true }], platforms: [:string, { multi: true }]
    attributes :name, :url, :kind, :description, :featured

    attribute(:id) { |app| app.id.to_s }

    attribute :icon_url do |app|
      Rails.application.routes.url_helpers.rails_blob_path(app.icon, only_path: true) if app.icon.attached?
    end

    attribute :platforms do |app|
      app.platforms.map { |key| AppDirectory::PLATFORMS.fetch(key).label }
    end

    many :uses, source: proc { uses.map { |key| Catalog::Taxonomy.type(key) } }, resource: AppUseResource
  end
end
