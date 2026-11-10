require 'clone_helper'

RSpec.describe 'Catalog search (/resources and /spotlight)', type: :request do
  let(:published) { DownloadableResource.published }

  # SQL statements a block sends to either database, without schema and transaction queries.
  def count_queries(&block)
    count = 0
    counter = lambda do |*, payload|
      count += 1 unless payload[:cached] || %w[SCHEMA TRANSACTION].include?(payload[:name])
    end
    ActiveSupport::Notifications.subscribed(counter, 'sql.active_record', &block)
    count
  end

  describe 'GET /resources with the catalog page group on', page_groups: %w[catalog] do
    it 'renders the catalog page with results, a total, facets and the echoed filters' do
      get '/resources'

      expect(response).to have_http_status(:ok)
      expect(controller).to be_a(Catalog::ResourcesController)
      expect(inertia).to render_component('catalog/CatalogPage')
      expect(inertia).to have_props(
        total: published.count,
        page: 1,
        filters: { q: '', type: nil, language: nil, script: [], format: nil, granularity: nil, status: nil,
                   sort: 'popular', page: 1 }
      )
      expect(inertia.props[:results].size).to eq(Catalog::SearchQuery::PER_PAGE)
      expect(inertia.props[:results].first.keys).to contain_exactly(
        'id', 'name', 'type', 'toParam', 'language', 'granularity', 'formats', 'status', 'recommended'
      )
      expect(inertia.props[:facets].keys).to contain_exactly('type', 'language', 'script', 'format', 'granularity',
                                                              'status')
      expect(inertia.props[:facets][:type]).to include({ value: 'translation',
                                                         count: published.where(resource_type: 'translation').count })
    end

    it 'sends the vocabularies once: labels for every facet value and sort' do
      get '/resources'

      vocabularies = inertia.props[:vocabularies]
      expect(vocabularies[:types].pluck(:key)).to eq(Catalog::Taxonomy.types.map(&:key))
      expect(vocabularies[:formats].pluck(:key)).to eq(Catalog::Taxonomy.formats.map(&:key))
      expect(vocabularies[:scriptFamilies].pluck(:key)).to eq(DownloadableResource.script_families.keys)
      expect(vocabularies[:statuses].pluck(:key)).to eq(DownloadableResource.statuses.keys)
      expect(vocabularies[:sorts].pluck(:key)).to eq(%w[popular name updated])
      expect(vocabularies[:granularities].pluck(:key)).to include('1_ayah', '1_word', '1_chapter')
      expect(vocabularies[:languages]).to include({ key: 'ar', name: 'Arabic', nativeName: 'العربية' })

      page = JSON.parse(Nokogiri::HTML(response.body).at('script[data-page="app"]').text)
      expect(page['onceProps'].keys).to include('vocabularies')
    end

    it 'applies the filters from the query string' do
      get '/resources', params: { q: 'english', type: 'translation', script: %w[madani indopak], sort: 'name' }

      expect(inertia.props[:filters]).to include(q: 'english', type: 'translation', script: %w[madani indopak],
                                                 sort: 'name')
      expected = Catalog::SearchQuery.new(
        Catalog::SearchFilters.from(q: 'english', type: 'translation', script: %w[madani indopak], sort: 'name')
      ).call
      expect(inertia.props[:total]).to eq(expected.total)
      expect(inertia.props[:results].pluck(:id)).to eq(expected.results.map { |row| row.resource.id })
    end

    it 'finds resources through an Arabic native language name' do
      get '/resources', params: { q: 'العربيّة', type: 'tafsir' }

      expect(inertia.props[:total]).to be > 0
      expect(inertia.props[:results].pluck(:language)).to all(eq('Arabic'))
    end

    it 'ignores invalid filter values instead of failing' do
      get '/resources', params: { type: 'nope', script: { 'x' => 'madani', 'y' => 'nope' }, format: ['json'],
                                  language: 'xx', status: '', sort: 'random', page: '-3', granularity: { a: 1 } }

      expect(response).to have_http_status(:ok)
      expect(inertia.props[:filters]).to include(type: nil, script: ['madani'], format: nil, language: nil,
                                                 status: nil, sort: 'popular', page: 1, granularity: nil)
      expect(inertia.props[:total]).to eq(published.where(script_family: 'madani').count)
    end

    it 'has the head tags of the catalog, with the canonical on the unfiltered page' do
      get '/resources', params: { type: 'font' }

      html = Nokogiri::HTML(response.body)
      expect(html.at('title').text).to eq('Resources - QUL')
      expect(html.at('meta[name="description"]')['content']).to be_present
      expect(html.at('link[rel="canonical"]')['href']).to eq('https://qul.tarteel.ai/resources')
    end

    it 'runs the same number of queries whatever the filters and result count' do
      get '/resources' # loads the code and the schema
      unfiltered = count_queries { get '/resources' }
      filtered = count_queries do
        get '/resources', params: { q: 'tafsir', type: 'tafsir', language: 'ar', format: 'json', status: 'stable',
                                    granularity: '1_ayah', sort: 'updated', page: 2 }
      end
      empty = count_queries { get '/resources', params: { q: 'zzzz-no-such-resource' } }

      expect(inertia.props[:total]).to eq(0)
      expect([filtered, empty]).to all(eq(unfiltered))
      expect(unfiltered).to be <= 8
    end
  end

  describe 'GET /resources with the catalog page group off', page_groups: [] do
    it 'renders the old catalog page' do
      get '/resources'

      expect(response).to have_http_status(:ok)
      expect(controller).to be_a(ResourcesController)
      expect(response.body).not_to include('data-page="app"')
    end
  end

  describe 'GET /spotlight' do
    it 'returns a few results as JSON for a query, marked noindex' do
      get '/spotlight', params: { q: 'tafsir' }, headers: { 'Accept' => 'application/json' }

      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq('application/json')
      expect(response.headers['X-Robots-Tag']).to eq('noindex')
      body = response.parsed_body
      expected = Catalog::SearchQuery.new(Catalog::SearchFilters.from(q: 'tafsir')).call
      expect(body['total']).to eq(expected.total)
      expect(body['total']).to be > Catalog::SpotlightController::LIMIT
      expect(body['results'].size).to eq(Catalog::SpotlightController::LIMIT)
      expect(body['results'].pluck('id')).to eq(expected.matches.first(Catalog::SpotlightController::LIMIT)
                                                         .map { |row| row.resource.id })
      expect(body['results'].first.keys).to contain_exactly('id', 'name', 'type', 'toParam', 'language')
    end

    it 'finds an Arabic query' do
      get '/spotlight', params: { q: 'الْعَرَبِيَّة' }

      expect(response.parsed_body['results'].pluck('language')).to include('Arabic')
    end

    it 'returns no results for a query nothing matches' do
      get '/spotlight', params: { q: 'zzzz-no-such-resource' }

      expect(response.parsed_body).to eq('results' => [], 'total' => 0)
    end
  end
end
