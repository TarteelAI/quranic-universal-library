# frozen_string_literal: true

require 'clone_helper'

# The directory lists the published App rows (AppDirectory), here the imported config/apps.yml.
RSpec.describe 'Apps directory (/apps)', type: :request do
  before { AppDirectory::Import.run }

  let(:published) { App.where(published: true) }
  let(:submission) do
    App.create!(name: 'Spec Unpublished Submission', url: 'https://example.test/unpublished', platforms: ['web'],
                uses: ['translation'], contact: 'maker@example.test', consent: true,)
  end

  def app_props(import_key)
    inertia.props[:apps].find { |app| app[:id] == App.find_by!(import_key:).id.to_s }
  end

  describe 'with the apps page group on', page_groups: ['apps', 'catalog'] do
    it 'renders exactly the published apps, featured first, server-rendered' do
      submission
      App.find_by!(import_key: 'nimaz').update!(featured: true)
      SsrServer.with_ssr { get '/apps' }

      expect(response).to have_http_status(:ok)
      expect(controller).to be_a(Site::AppsController)
      expect(inertia).to render_component('site/AppsPage')
      featured, rest = published.order(:id).partition(&:featured)
      expect(inertia.props[:apps].pluck(:id)).to eq((featured + rest).map { |app| app.id.to_s })
      expect(inertia.props[:total]).to eq(published.count)
      expect(featured.map(&:import_key)).to include('nimaz')

      app = Nokogiri::HTML(response.body).at('#app[data-server-rendered="true"]')
      expect(app.css('ul[aria-label="Apps"] > li').size).to eq(published.count)
      expect(response.body).not_to include('Spec Unpublished Submission')
    end

    it 'gives each app its icon, platforms and the resource types it uses, and never the contact' do
      App.find_by!(import_key: 'quranwbw').update!(contact: 'maker@example.test')
      get '/apps'

      quranwbw = app_props('quranwbw')
      expect(quranwbw.keys.map(&:to_s)).to match_array(['id', 'name', 'url', 'kind', 'description', 'featured',
                                                        'iconUrl', 'platforms', 'uses',])
      expect(quranwbw).to include(name: 'QuranWBW', url: 'https://quranwbw.com', kind: 'Word by word',
                                  platforms: ['Web'], featured: true,
                                  uses: [{ key: 'translation', label: 'Translation', category: 'translation' }],)
      expect(quranwbw[:iconUrl]).to match(%r{\A/rails/active_storage/blobs/redirect/[^/]+/icon\.png\z})
      expect(app_props('quran-validator')[:iconUrl]).to be_nil
      expect(response.body).not_to include('maker@example.test')
      expect(inertia.props[:platforms].pluck(:key)).to eq(AppDirectory::PLATFORMS.keys)
      used = AppDirectory.apps.flat_map(&:uses).uniq
      expect(inertia.props[:types].pluck(:key)).to match_array(used)
      expect(inertia.props[:submissionTypes].pluck(:key)).to eq(Catalog::Taxonomy.types.map(&:key))
      expect(inertia.props).not_to have_key(:submitUrl)
    end

    it 'narrows the list by platform and by resource type, from the query string' do
      get '/apps', params: { platform: 'android', type: 'mushaf-layout' }

      expected = AppDirectory.apps.select do |app|
        app.platforms.include?('android') && app.uses.include?('mushaf-layout')
      end
      expect(expected).not_to be_empty
      expect(inertia.props[:apps].pluck(:id)).to eq(expected.map { |app| app.id.to_s })
      expect(inertia.props[:filters]).to include(platform: 'android', type: 'mushaf-layout')
      expect(inertia.props[:total]).to eq(AppDirectory.apps.size)
    end

    it 'shows no unpublished submission in the search pop-up' do
      submission

      get '/spotlight', params: { q: 'Spec Unpublished Submission' }

      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include('Spec Unpublished Submission')
    end

    it 'drops a filter value no app can have' do
      get '/apps', params: { platform: 'palm-os', type: 'hadith' }

      expect(inertia.props[:filters]).to include(platform: nil, type: nil)
      expect(inertia.props[:apps].size).to eq(AppDirectory.apps.size)
    end

    it 'puts the head on the page: title, description, canonical, Open Graph, JSON-LD' do
      get '/apps'

      html = Nokogiri::HTML(response.body)
      expect(html.at('title').text).to eq('Apps built with QUL')
      expect(html.at('meta[name="description"]')['content']).to start_with('Quran readers, study apps')
      expect(html.at('link[rel="canonical"]')['href']).to eq('https://qul.tarteel.ai/apps')
      expect(html.at('meta[property="og:url"]')['content']).to eq('https://qul.tarteel.ai/apps')
      expect(html.at('meta[property="og:title"]')['content']).to eq('Apps built with QUL')
      json_ld = JSON.parse(html.at('script[type="application/ld+json"]').text)
      expect(json_ld).to include('@type' => 'CollectionPage', 'url' => 'https://qul.tarteel.ai/apps',
                                 'isPartOf' => include('@type' => 'WebSite'),)
    end
  end

  describe 'with the apps page group off', page_groups: ['home', 'catalog'] do
    it 'is a 404, as on main' do
      get '/apps'

      expect(response).to have_http_status(:not_found)
    end
  end
end
