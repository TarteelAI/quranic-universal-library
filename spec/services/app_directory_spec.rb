# frozen_string_literal: true

require 'clone_helper'

RSpec.describe AppDirectory do
  let(:data) { described_class.data }
  let(:entries) { data.fetch('apps') }

  it 'loads the data file: unique ids, known types, platforms and resource types, and icons that exist' do
    expect(entries.size).to be >= 20
    ids = entries.pluck('id')
    expect(ids.uniq).to eq(ids)

    entries.each do |entry|
      keys = ['id', 'name', 'url', 'source_url', 'icon', 'project_type', 'platforms', 'kind', 'description', 'uses',
              'evidence', 'position',]
      expect(entry.keys - keys).to be_empty, entry['id']
      expect(entry.values_at('id', 'name', 'kind', 'description')).to all(be_present), entry['id']
      expect(entry['url']).to start_with('https://'), entry['id']
      expect(entry['evidence']).to start_with('https://'), entry['id']
      expect([entry['url'], *entry['source_url']].uniq.size).to eq(entry.key?('source_url') ? 2 : 1), entry['id']
      if entry.key?('project_type')
        expect(described_class::PROJECT_TYPES.keys - ['app']).to include(entry['project_type']), entry['id']
        expect(entry).not_to have_key('platforms'), entry['id']
      else
        expect(entry['platforms']).to be_present.and(all(be_in(described_class::PLATFORMS.keys))), entry['id']
      end
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

    it 'lists the published apps, the featured ones (with a position) first, then in the order they were imported' do
      submission = App.create!(name: 'Unpublished', url: 'https://example.test/app', platforms: ['web'],
                               uses: ['translation'],)
      featured, rest = entries.partition { |entry| entry['position'] }
      featured = featured.sort_by { |entry| entry['position'] }

      apps = described_class.apps
      expect(apps.map(&:import_key)).to eq((featured + rest).pluck('id'))
      expect(apps).not_to include(submission)
    end

    it 'features an app given a position, in position order, and unfeatures one whose position is cleared' do
      App.find_by!(import_key: 'bayaan').update!(position: 0)
      App.find_by!(import_key: 'quranwbw').update!(position: nil)

      keys = described_class.apps.map(&:import_key)
      expect(keys.first).to eq('bayaan')
      featured = entries.count { |entry| entry['position'] }
      expect(keys.index('quranwbw')).to be >= featured
      expect(App.create!(name: 'New', url: 'https://example.test/new', platforms: ['web'], uses: ['translation'])
        .position).to be_nil
    end

    it 'filters by platform and resource type' do
      apps = described_class.apps
      filters = described_class.filters(project_type: nil, platform: 'ios', type: 'font')

      expect(described_class.filter(apps, filters).map(&:id))
        .to eq(apps.select { |app| app.platforms.include?('ios') && app.uses.include?('font') }.map(&:id))
    end

    it 'filters by type, and imports a type with no platforms' do
      apps = described_class.apps
      libraries = described_class.filter(apps,
                                         described_class.filters(project_type: 'library', platform: nil, type: nil),)

      expect(libraries.map(&:import_key)).to include('quran-library', 'quranic-phonemizer')
      expect(libraries).to all(have_attributes(project_type: 'library', platforms: []))
    end
  end
end
