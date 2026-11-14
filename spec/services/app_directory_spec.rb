# frozen_string_literal: true

require 'clone_helper'

RSpec.describe AppDirectory do
  let(:data) { described_class.data }
  let(:entries) { data.fetch('apps') }

  it 'loads the data file: unique ids, known platforms and resource types, and icons that exist' do
    expect(entries.size).to be >= 20
    ids = entries.pluck('id')
    expect(ids.uniq).to eq(ids)

    entries.each do |entry|
      keys = ['id', 'name', 'url', 'icon', 'platforms', 'kind', 'description', 'uses', 'evidence', 'featured']
      expect(entry.keys - keys).to be_empty, entry['id']
      expect(entry.values_at('id', 'name', 'kind', 'description')).to all(be_present), entry['id']
      expect(entry['url']).to start_with('https://'), entry['id']
      expect(entry['evidence']).to start_with('https://'), entry['id']
      expect(entry['platforms']).to be_present.and(all(be_in(described_class::PLATFORMS.keys))), entry['id']
      expect(entry['uses']).to be_present.and(all(satisfy { |key| Catalog::Taxonomy.type(key) })), entry['id']
      expect(described_class::ICONS_DIR.join(entry['icon'])).to exist, entry['id'] if entry['icon']
    end
  end

  it 'has an entry for every icon file' do
    icons = entries.filter_map { |entry| entry['icon'] }
    expect(Dir.children(described_class::ICONS_DIR)).to match_array(icons)
  end

  describe 'the directory' do
    before { AppDirectory::Import.run }

    it 'lists the published apps, featured first, then in the order they were imported' do
      submission = App.create!(name: 'Unpublished', url: 'https://example.test/app', platforms: ['web'],
                               uses: ['translation'],)
      featured, rest = entries.partition { |entry| entry['featured'] }

      apps = described_class.apps
      expect(apps.map(&:import_key)).to eq((featured + rest).pluck('id'))
      expect(apps).not_to include(submission)
    end

    it 'filters by platform and resource type' do
      apps = described_class.apps
      filters = described_class.filters(platform: 'ios', type: 'font')

      expect(described_class.filter(apps, filters).map(&:id))
        .to eq(apps.select { |app| app.platforms.include?('ios') && app.uses.include?('font') }.map(&:id))
    end
  end
end
