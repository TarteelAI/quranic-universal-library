# frozen_string_literal: true

module Site
  # An entry of the apps directory (AppDirectory::App). Its platforms are labels.
  class AppResource < ApplicationResource
    typelize id: :string, name: :string, url: :string, kind: :string, description: :string, featured: :boolean,
             icon_url: [:string, { nullable: true }], platforms: [:string, { multi: true }]
    attributes :id, :name, :url, :kind, :description, :featured

    attribute :icon_url do |app|
      "#{AppDirectory::ICONS_PATH}/#{app.icon}" if app.icon
    end

    attribute :platforms do |app|
      app.platforms.map { |key| AppDirectory::PLATFORMS.fetch(key).label }
    end

    many :uses, source: proc { uses.map { |key| Catalog::Taxonomy.type(key) } }, resource: AppUseResource
  end
end
