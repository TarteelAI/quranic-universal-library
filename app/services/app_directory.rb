# frozen_string_literal: true

# The apps built with QUL, for the /apps directory and the home page's apps band: the published
# App rows. config/apps.yml and public/app-icons are the source `apps:import` reads once
# (AppDirectory::Import); the pages never read them.
module AppDirectory
  Platform = Data.define(:key, :label)
  Filters = Data.define(:platform, :type)

  FILE = Rails.root.join('config', 'apps.yml')
  ICONS_DIR = Rails.public_path.join('app-icons')
  # The apps of the home page's band: the first of the directory.
  SHOWCASE_SIZE = 8

  PLATFORMS = [
    Platform.new(key: 'ios', label: 'iOS'),
    Platform.new(key: 'android', label: 'Android'),
    Platform.new(key: 'web', label: 'Web'),
    Platform.new(key: 'desktop', label: 'Desktop'),
    Platform.new(key: 'library', label: 'Library'),
    Platform.new(key: 'tool', label: 'Tool'),
    Platform.new(key: 'dataset', label: 'Dataset'),
  ].index_by(&:key).freeze

  def self.data
    YAML.safe_load_file(FILE)
  end

  # Every published app, featured first.
  def self.apps
    App.directory.with_attached_icon.to_a
  end

  # The filters of a request, without values no app can have.
  def self.filters(platform:, type:)
    Filters.new(
      platform: PLATFORMS.key?(platform) ? platform : nil,
      type: Catalog::Taxonomy.type(type) ? type : nil,
    )
  end

  def self.filter(apps, filters)
    apps.select do |app|
      (filters.platform.nil? || app.platforms.include?(filters.platform)) &&
        (filters.type.nil? || app.uses.include?(filters.type))
    end
  end
end
