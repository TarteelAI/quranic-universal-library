# frozen_string_literal: true

module AppDirectory
  # Imports the entries of config/apps.yml, with their icons from public/app-icons, as published
  # App rows (`bin/rails apps:import`), keyed on the entry id (`import_key`). An entry that already
  # has a row is skipped whatever the row holds now, so a second run changes nothing and an
  # editor's change is never overwritten. An imported app an editor removed comes back on the next
  # run: the import is a one-time step.
  module Import
    # Creates the rows of the entries that have none, in the file's order, and returns how many.
    def self.run
      imported = App.where.not(import_key: nil).pluck(:import_key).to_set
      entries = AppDirectory.data.fetch('apps').reject { |entry| imported.include?(entry['id']) }
      App.transaction { entries.each { |entry| create(entry) } }
      entries.size
    end

    def self.create(entry)
      app = App.new(
        import_key: entry['id'], published: true, featured: entry.fetch('featured', false),
        **entry.slice('name', 'url', 'platforms', 'uses', 'kind', 'description', 'evidence').symbolize_keys,
      )
      # The bytes, because the upload runs when the transaction commits, after a file would be closed.
      app.icon_upload = StringIO.new(File.binread(ICONS_DIR.join(entry['icon']))) if entry['icon']
      app.save!
    end
    private_class_method :create
  end
end
