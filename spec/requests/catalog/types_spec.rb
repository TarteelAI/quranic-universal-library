require 'clone_helper'

RSpec.describe 'Type pages (/resources/:type)', type: :request do
  let(:types) { DownloadableResource::RESOURCE_TYPES }

  describe 'with the catalog page group on', page_groups: %w[catalog] do
    it 'renders the Inertia page for each of the 14 types, with one card per published resource' do
      expect(types.size).to eq(14)

      types.each do |type|
        get "/resources/#{type}"

        expect(response).to have_http_status(:ok)
        expect(controller).to be_a(Catalog::TypesController)
        expect(inertia).to render_component('catalog/TypePage')
        expect(inertia.props[:type]).to include(key: type)
        published = DownloadableResource.published.where(resource_type: type)
        expect(inertia.props[:resources].pluck(:id)).to match_array(published.ids), type
        expect(inertia.props[:resources].pluck(:name)).to all(be_present)
      end
    end

    it 'sends the taxonomy as props: every type, with its category' do
      get '/resources/translation'

      expect(inertia.props[:types].pluck(:key)).to eq(Catalog::Taxonomy.types.map(&:key))
      expect(inertia.props[:type]).to include(
        title: 'Translations',
        category: { key: 'translation', label: 'Translation' }
      )
    end

    it 'gives each card its detail path, language and granularity' do
      get '/resources/translation'

      resource = DownloadableResource.published.where(resource_type: 'translation').where.not(language_id: nil).first
      card = inertia.props[:resources].find { |c| c[:id] == resource.id }
      expect(card).to include(
        name: resource.name,
        type: 'translation',
        toParam: resource.to_param,
        language: resource.language.name,
        granularity: resource.humanize_cardinality_type,
        filesCount: resource.files_count
      )
    end

    it 'takes the language from the content row when the resource row has none' do
      resource = DownloadableResource.published.where(resource_type: 'translation', language_id: nil)
                                     .find { |r| r.resource_content&.language }
      skip 'every published translation has a language on its resource row' unless resource

      get '/resources/translation'

      card = inertia.props[:resources].find { |c| c[:id] == resource.id }
      expect(card[:language]).to eq(resource.resource_content.language.name)
    end

    it 'returns 404 with the Inertia error page in the new layout for an unknown type' do
      get '/resources/no-such-type'

      expect(response).to have_http_status(:not_found)
      expect(inertia).to render_component('errors/ErrorPage')
      expect(inertia).to have_props(status: 404)
      html = Nokogiri::HTML(response.body)
      expect(html.at('meta[name="turbo-visit-control"]')['content']).to eq('reload')
      expect(html.at('meta[name="robots"]')['content']).to eq('noindex')
      expect(html.at('title').text).to eq('Page not found - QUL')
    end

    it 'returns 404 for a format variant of a type page' do
      get '/resources/translation.json'

      expect(response).to have_http_status(:not_found)
    end

    it 'puts the head on the page: title, description, canonical, Open Graph, Twitter, JSON-LD' do
      get '/resources/mushaf-layout'

      html = Nokogiri::HTML(response.body)
      type = Catalog::Taxonomy.type('mushaf-layout')
      expect(html.at('title').text).to eq('Mushaf layouts - QUL')
      expect(html.at('meta[name="description"]')['content']).to eq(type.description)
      expect(html.at('link[rel="canonical"]')['href']).to eq('https://qul.tarteel.ai/resources/mushaf-layout')
      expect(html.at('meta[property="og:title"]')['content']).to eq('Mushaf layouts - QUL')
      expect(html.at('meta[property="og:url"]')['content']).to eq('https://qul.tarteel.ai/resources/mushaf-layout')
      expect(html.at('meta[property="og:image"]')['content']).to be_present
      expect(html.at('meta[name="twitter:card"]')['content']).to eq('summary_large_image')
      expect(html.at('meta[name="twitter:title"]')['content']).to eq('Mushaf layouts - QUL')
      json_ld = JSON.parse(html.at('script[type="application/ld+json"]').text)
      expect(json_ld).to include(
        '@type' => 'CollectionPage',
        'url' => 'https://qul.tarteel.ai/resources/mushaf-layout',
        'name' => 'Mushaf layouts - QUL'
      )
    end

    it 'loads GA4 without its own page view, and the Sentry loader' do
      get '/resources/font'

      html = Nokogiri::HTML(response.body)
      expect(html.css('script[src]').map { |s| s['src'] }).to include(
        'https://www.googletagmanager.com/gtag/js?id=G-57749XV2P9',
        a_string_starting_with('https://js.sentry-cdn.com/')
      )
      expect(response.body).to include("gtag('config', 'G-57749XV2P9', { send_page_view: false })")
    end

    it 'server-renders the type name and the resource names into the first response' do
      SsrServer.with_ssr { get '/resources/tafsir' }

      expect(response).to have_http_status(:ok)
      app = Nokogiri::HTML(response.body).at('#app[data-server-rendered="true"]')
      expect(app).to be_present
      expect(app.at('h1').text).to start_with('Tafsirs')
      card_names = app.css('article h3').map(&:text)
      expect(card_names).to match_array(DownloadableResource.published.where(resource_type: 'tafsir').pluck(:name))

      head = Nokogiri::HTML(response.body).at('head')
      expect(head.at('title').text).to eq('Tafsirs - QUL')
      expect(head.at('link[rel="canonical"]')['href']).to eq('https://qul.tarteel.ai/resources/tafsir')
      expect(JSON.parse(head.at('script[type="application/ld+json"]').text)).to include('@type' => 'CollectionPage')
    end
  end

  describe 'with the catalog page group off', page_groups: [] do
    it 'renders the old ERB view at the same URLs' do
      %w[translation mushaf-layout surah-info].each do |type|
        get "/resources/#{type}"

        expect(response).to have_http_status(:ok)
        expect(controller).to be_a(ResourcesController)
        expect(response.body).not_to include('data-page="app"')
      end
    end
  end
end
