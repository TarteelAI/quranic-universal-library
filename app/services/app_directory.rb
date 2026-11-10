# frozen_string_literal: true

# The apps built with QUL: the entries of config/apps.yml, for the /apps directory and the home
# page's showcase. The file can become a table later; the pages read only this module's values.
module AppDirectory
  Platform = Data.define(:key, :label)
  App = Data.define(:id, :name, :url, :icon, :platforms, :kind, :description, :uses, :evidence, :featured)
  Filters = Data.define(:platform, :type)

  FILE = Rails.root.join('config/apps.yml')
  ICONS_DIR = Rails.root.join('public/app-icons')
  ICONS_PATH = '/app-icons'
  SUBMIT_URL = "#{SiteNav::REPO_URL}/issues/new?template=app_submission.yml".freeze

  PLATFORMS = [
    Platform.new(key: 'ios', label: 'iOS'),
    Platform.new(key: 'android', label: 'Android'),
    Platform.new(key: 'web', label: 'Web'),
    Platform.new(key: 'desktop', label: 'Desktop'),
    Platform.new(key: 'library', label: 'Library'),
    Platform.new(key: 'tool', label: 'Tool'),
    Platform.new(key: 'dataset', label: 'Dataset')
  ].index_by(&:key).freeze

  def self.data
    YAML.safe_load_file(FILE)
  end

  # Every app, featured first, then in the file's order.
  def self.apps
    entries = data.fetch('apps').map do |entry|
      App.new(featured: false, icon: nil, **entry.symbolize_keys)
    end
    entries.partition(&:featured).flatten
  end

  def self.showcase
    by_id = apps.index_by(&:id)
    data.fetch('showcase').map { |id| by_id.fetch(id) }
  end

  # The filters of a request, without values no app can have.
  def self.filters(platform:, type:)
    Filters.new(
      platform: PLATFORMS.key?(platform) ? platform : nil,
      type: Catalog::Taxonomy.type(type) ? type : nil
    )
  end

  def self.filter(apps, filters)
    apps.select do |app|
      (filters.platform.nil? || app.platforms.include?(filters.platform)) &&
        (filters.type.nil? || app.uses.include?(filters.type))
    end
  end
end
