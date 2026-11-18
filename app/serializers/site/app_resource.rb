# frozen_string_literal: true

module Site
  # A published app of the apps directory (App). Its type and platforms are labels. Never the contact.
  class AppResource < ApplicationResource
    typelize id: :string, name: :string, url: :string, kind: :string, description: :string, featured: :boolean,
             project_type: :string, icon_url: [:string, { nullable: true }], platforms: [:string, { multi: true }],
             app_store_url: [:string, { nullable: true }], play_store_url: [:string, { nullable: true }],
             source_url: [:string, { nullable: true }]
    attributes :name, :url, :kind, :description, :featured, :app_store_url, :play_store_url, :source_url

    attribute(:project_type) { |app| AppDirectory::PROJECT_TYPES.fetch(app.project_type).label }

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
