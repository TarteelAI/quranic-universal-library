# frozen_string_literal: true

# The apps built with QUL, for the /apps directory and the home page's apps band: the published
# App rows. config/apps.yml and public/app-icons are the source `apps:import` reads once
# (AppDirectory::Import); the pages never read them.
module AppDirectory
  Option = Data.define(:key, :label)
  Filters = Data.define(:project_type, :platform, :type)

  FILE = Rails.root.join('config', 'apps.yml')
  ICONS_DIR = Rails.public_path.join('app-icons')
  # The apps of the home page's band: the first of the directory.
  SHOWCASE_SIZE = 8

  # What an app is. Only an app (something people open or install) has platforms and store links;
  # the others are for developers.
  PROJECT_TYPES = [
    Option.new(key: 'app', label: 'App'),
    Option.new(key: 'library', label: 'Library'),
    Option.new(key: 'tool', label: 'Tool'),
    Option.new(key: 'data', label: 'Data or API'),
  ].index_by(&:key).freeze

  # Where an app runs.
  PLATFORMS = [
    Option.new(key: 'ios', label: 'iOS'),
    Option.new(key: 'android', label: 'Android'),
    Option.new(key: 'web', label: 'Web'),
    Option.new(key: 'desktop', label: 'Desktop'),
  ].index_by(&:key).freeze

  def self.data
    YAML.safe_load_file(FILE)
  end

  # Every published app, featured first.
  def self.apps
    App.directory.with_attached_icon.to_a
  end

  # The filters of a request, without values no app can have.
  def self.filters(project_type:, platform:, type:)
    Filters.new(
      project_type: PROJECT_TYPES.key?(project_type) ? project_type : nil,
      platform: PLATFORMS.key?(platform) ? platform : nil,
      type: Catalog::Taxonomy.type(type) ? type : nil,
    )
  end

  def self.filter(apps, filters)
    apps.select do |app|
      (filters.project_type.nil? || app.project_type == filters.project_type) &&
        (filters.platform.nil? || app.platforms.include?(filters.platform)) &&
        (filters.type.nil? || app.uses.include?(filters.type))
    end
  end
end
