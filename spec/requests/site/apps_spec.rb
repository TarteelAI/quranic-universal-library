# frozen_string_literal: true

require 'clone_helper'

RSpec.describe 'Apps directory (/apps)', type: :request do
  describe 'with the apps page group on', page_groups: ['apps', 'catalog'] do
    it 'renders every app of the data file, featured first, server-rendered' do
      SsrServer.with_ssr { get '/apps' }

      expect(response).to have_http_status(:ok)
      expect(controller).to be_a(Site::AppsController)
      expect(inertia).to render_component('site/AppsPage')
      ids = AppDirectory.data.fetch('apps').pluck('id')
      expect(inertia.props[:apps].pluck(:id)).to match_array(ids)
      expect(inertia.props[:total]).to eq(ids.size)
      featured = inertia.props[:apps].pluck(:featured)
      expect(featured).to eq(featured.sort_by { |flag| flag ? 0 : 1 })
      expect(featured).to include(true)

      app = Nokogiri::HTML(response.body).at('#app[data-server-rendered="true"]')
      expect(app.css('ul[aria-label="Apps"] > li').size).to eq(ids.size)
    end

    it 'gives each app its icon, platforms and the resource types it uses' do
      get '/apps'

      quranwbw = inertia.props[:apps].find { |app| app[:id] == 'quranwbw' }
      expect(quranwbw).to include(name: 'QuranWBW', url: 'https://quranwbw.com', iconUrl: '/app-icons/quranwbw.png',
                                  platforms: ['Web'], featured: true,
                                  uses: [{ key: 'translation', label: 'Translation', category: 'translation' }],)
      expect(inertia.props[:apps].find { |app| app[:id] == 'quran-validator' }[:iconUrl]).to be_nil
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
      expect(inertia.props[:apps].pluck(:id)).to eq(expected.map(&:id))
      expect(inertia.props[:filters]).to include(platform: 'android', type: 'mushaf-layout')
      expect(inertia.props[:total]).to eq(AppDirectory.apps.size)
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
