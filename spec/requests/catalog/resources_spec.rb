# frozen_string_literal: true

require 'clone_helper'

RSpec.describe 'Catalog search (/resources and /spotlight)', type: :request do
  let(:published) { DownloadableResource.published }

  # SQL statements a block sends to either database, without schema and transaction queries.
  def count_queries(&)
    count = 0
    counter = lambda do |*, payload|
      count += 1 unless payload[:cached] || ['SCHEMA', 'TRANSACTION'].include?(payload[:name])
    end
    ActiveSupport::Notifications.subscribed(counter, 'sql.active_record', &)
    count
  end

  describe 'GET /resources with the catalog page group on', page_groups: ['catalog'] do
    it 'renders the catalog page with results, a total, facets and the echoed filters' do
      get '/resources'

      expect(response).to have_http_status(:ok)
      expect(controller).to be_a(Catalog::ResourcesController)
      expect(inertia).to render_component('catalog/CatalogPage')
      expect(inertia).to have_props(
        total: published.count,
        page: 1,
        filters: { q: '', type: nil, language: nil, script: [], format: nil, granularity: nil, status: nil,
                   sort: nil, page: 1, view: 'grid', },
      )
      expect(inertia.props[:results].size).to eq(Catalog::SearchQuery::PER_PAGE)
      expect(inertia.props[:results].first.keys).to contain_exactly(
        'id', 'name', 'type', 'toParam', 'summary', 'language', 'granularity', 'formats', 'status', 'recommended',
        'previewKind',
      )
      expect(inertia.props[:facets].keys).to contain_exactly('type', 'language', 'script', 'format', 'granularity',
                                                             'status',)
      expect(inertia.props[:facets][:type]).to include({ value: 'translation',
                                                         count: published.where(resource_type: 'translation').count, })
    end

    it 'sends the vocabularies once: labels for every facet value and sort' do
      get '/resources'

      vocabularies = inertia.props[:vocabularies]
      expect(vocabularies[:types].pluck(:key)).to eq(Catalog::Taxonomy.types.map(&:key))
      # Only what the filters and cards show: the type pages carry each type's copy.
      expect(vocabularies[:types].first.keys).to contain_exactly('key', 'label', 'category')
      expect(vocabularies[:formats].pluck(:key)).to eq(Catalog::Taxonomy.formats.map(&:key))
      expect(vocabularies[:scriptFamilies].pluck(:key)).to eq(DownloadableResource.script_families.keys)
      expect(vocabularies[:statuses].pluck(:key)).to eq(DownloadableResource.statuses.keys)
      expect(vocabularies[:sorts].pluck(:key)).to eq(['popular', 'name', 'updated'])
      expect(vocabularies[:granularities].pluck(:key)).to include('1_ayah', '1_word', '1_chapter')
      expect(vocabularies[:languages]).to include({ key: 'ar', name: 'Arabic', nativeName: 'العربية' })

      page = JSON.parse(Nokogiri::HTML(response.body).at('script[data-page="app"]').text)
      expect(page['onceProps'].keys).to include('vocabularies')
    end

    it 'applies the filters from the query string' do
      get '/resources', params: { q: 'english', type: 'translation', script: ['madani', 'indopak'], sort: 'name' }

      expect(inertia.props[:filters]).to include(q: 'english', type: 'translation', script: ['madani', 'indopak'],
                                                 sort: 'name',)
      expected = Catalog::SearchQuery.new(
        Catalog::SearchFilters.from(q: 'english', type: 'translation', script: ['madani', 'indopak'], sort: 'name'),
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
                                  language: 'xx', status: '', sort: 'random', page: '-3', granularity: { a: 1 }, }

      expect(response).to have_http_status(:ok)
      expect(inertia.props[:filters]).to include(type: nil, script: ['madani'], format: nil, language: nil,
                                                 status: nil, sort: nil, page: 1, granularity: nil,)
      expect(inertia.props[:total]).to eq(published.where(script_family: 'madani').count)
    end

    it 'has the head tags of the catalog, with the canonical on the unfiltered page' do
      get '/resources', params: { type: 'font' }

      html = Nokogiri::HTML(response.body)
      expect(html.at('title').text).to eq('Resources - QUL')
      expect(html.at('meta[name="description"]')['content']).to be_present
      expect(html.at('link[rel="canonical"]')['href']).to eq('https://qul.tarteel.ai/resources')
    end

    it 'server-renders the view of the URL, with the controls showing its filters' do
      query = 'q=english&script[]=madani&script[]=indopak&format=json&sort=name'
      SsrServer.with_ssr { get "/resources?#{query}" }

      expect(response).to have_http_status(:ok)
      app = Nokogiri::HTML(response.body).at('#app[data-server-rendered="true"]')
      expect(app).to be_present
      expect(app.at('input[type="search"]')['value']).to eq('english')
      expect(app.at('select option[selected]')['value']).to eq('name')
      rail = app.at('aside[aria-label="Filters"]')
      checked = rail.css('label:has(button[aria-checked="true"]) span.truncate').map(&:text)
      expect(checked).to contain_exactly('Madani', 'IndoPak', 'JSON')
      chips = app.css('[aria-label="Active filters"] button[aria-label^="Remove"]').map { |chip| chip['aria-label'] }
      expect(chips).to eq(['Remove “english”', 'Remove Madani', 'Remove IndoPak', 'Remove JSON'])

      expected = Catalog::SearchQuery.new(
        Catalog::SearchFilters.from(q: 'english', script: ['madani', 'indopak'], format: 'json', sort: 'name'),
      ).call
      expect(app.at('h1 span').text).to eq(expected.total.to_s)
      expect(app.css('ul[aria-label="Resources"] article h3').map(&:text))
        .to eq(expected.results.map { |row| row.resource.display_name })
    end

    it 'points the canonical of every filtered view at the unfiltered catalog' do
      ['q=tafsir', 'script[]=madani&script[]=indopak', 'format=json&sort=updated&page=2', 'language=ur&type=tafsir']
        .each do |query|
        get "/resources?#{query}"

        head = Nokogiri::HTML(response.body).at('head')
        expect(head.at('link[rel="canonical"]')['href']).to eq('https://qul.tarteel.ai/resources'), query
        expect(head.at('title').text).to eq('Resources - QUL')
        expect(head.at('meta[name="description"]')['content']).to eq(Catalog::ResourcesController::DESCRIPTION)
      end
    end

    it 'runs the same number of queries whatever the filters and result count' do
      get '/resources' # loads the code and the schema
      unfiltered = count_queries { get '/resources' }
      filtered = count_queries do
        get '/resources', params: { q: 'tafsir', type: 'tafsir', language: 'ar', format: 'json', status: 'stable',
                                    granularity: '1_ayah', sort: 'updated', page: 2, }
      end
      empty = count_queries { get '/resources', params: { q: 'zzzz-no-such-resource' } }

      expect(inertia.props[:total]).to eq(0)
      expect([filtered, empty]).to all(eq(unfiltered))
      expect(unfiltered).to be <= 8
    end
  end

  describe 'GET /resources: grouping by category', page_groups: ['catalog'] do
    let(:category_order) { Catalog::Taxonomy::CATEGORIES.keys }

    def category_of(result)
      Catalog::Taxonomy.type(result[:type]).category.key
    end

    it 'groups the results by category in taxonomy order with no sort and no query, across pages' do
      ranks = [1, 6, 7].flat_map do |page|
        get '/resources', params: { page: page }

        expect(inertia.props[:filters]).to include(sort: nil, q: '')
        groups = inertia.props[:groups]
        categories = inertia.props[:results].map { |result| category_of(result) }
        expect(groups.map { |group| group[:category][:key] }).to eq(categories.uniq)
        expect(groups.sum { |group| group[:count] }).to eq(inertia.props[:results].size)
        groups.each do |group|
          key = group[:category][:key]
          expect(group[:category][:label]).to eq(Catalog::Taxonomy::CATEGORIES.fetch(key).label)
          expect(group[:total]).to eq(
            published.where(resource_type: Catalog::Taxonomy.types.select { |t| t.category.key == key }.map(&:key))
                     .count,
          )
        end
        categories.map { |key| category_order.index(key) }
      end
      expect(ranks).to eq(ranks.sort)
      expect(ranks.uniq.size).to be > 1
    end

    it 'sends one list, most downloaded first, when a sort is chosen' do
      get '/resources', params: { sort: 'popular' }

      expect(inertia.props[:filters]).to include(sort: 'popular')
      expect(inertia.props[:groups]).to be_nil
      expected = Catalog::SearchQuery.new(Catalog::SearchFilters.from(sort: 'popular')).call
      expect(inertia.props[:results].pluck(:id)).to eq(expected.results.map { |row| row.resource.id })
    end

    it 'sends one list when there is a query' do
      get '/resources', params: { q: 'english' }

      expect(inertia.props[:groups]).to be_nil
      expected = Catalog::SearchQuery.new(Catalog::SearchFilters.from(q: 'english', sort: 'popular')).call
      expect(inertia.props[:results].pluck(:id)).to eq(expected.results.map { |row| row.resource.id })
      categories = inertia.props[:results].map { |result| category_order.index(category_of(result)) }
      expect(categories).not_to eq(categories.sort)
    end

    it 'keeps the view in the filters: grid unless the URL asks for the list' do
      get '/resources'
      expect(inertia.props[:filters]).to include(view: 'grid')

      get '/resources', params: { view: 'list', q: 'english' }
      expect(inertia.props[:filters]).to include(view: 'list', q: 'english')

      get '/resources', params: { view: 'table' }
      expect(inertia.props[:filters]).to include(view: 'grid')
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
      expect(body['results'].first.keys).to contain_exactly('id', 'name', 'type', 'typeLabel', 'category', 'toParam',
                                                            'language', 'formats',)
    end

    it 'names the category and the format labels of each result, and no download counts' do
      get '/spotlight', params: { q: 'tafsir' }

      row = Catalog::SearchQuery.new(Catalog::SearchFilters.from(q: 'tafsir')).call.matches.first
      result = response.parsed_body['results'].first
      expect(result['category']).to eq(Catalog::Taxonomy.type(row.resource.resource_type).category.key)
      expect(result['formats']).to eq(row.formats.map { |key| Catalog::Taxonomy.label(Catalog::Taxonomy.formats, key) })
      expect(response.body).not_to match(/download/i)
    end

    it 'returns the most popular resources, as the catalog sorts them, without a query' do
      get '/spotlight'

      expected = Catalog::SearchQuery.new(Catalog::SearchFilters.from(sort: 'popular')).call
      body = response.parsed_body
      expect(response.headers['X-Robots-Tag']).to eq('noindex')
      expect(body['total']).to eq(expected.total)
      expect(body['results'].pluck('id')).to eq(expected.matches.first(Catalog::SpotlightController::POPULAR_LIMIT)
                                                         .map { |row| row.resource.id })
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
