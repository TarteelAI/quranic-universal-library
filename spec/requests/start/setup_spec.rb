# frozen_string_literal: true

require 'clone_helper'

# The guided setup (/start) and its results, the catalog URL with the answers (/resources?goal=…).
RSpec.describe 'Guided setup (/start)', type: :request do
  let(:complete) { 'goal=reader&platform=android,ios&feature=mushaf,translation&script=madani&lang=en,ur' }

  describe 'with the start and catalog page groups on', page_groups: ['start', 'catalog'] do
    it 'renders the five steps from the first, server-rendered' do
      SsrServer.with_ssr { get '/start' }

      expect(response).to have_http_status(:ok)
      expect(controller).to be_a(Start::SetupController)
      expect(inertia).to render_component('start/SetupPage')
      expect(inertia.props[:goals].pluck(:key)).to eq(GuidedSetup::GOALS.keys)
      expect(inertia.props[:goals].first).to include(key: 'reader', features: ['mushaf', 'translation', 'nav'])
      expect(inertia.props[:platforms].pluck(:key)).to eq(GuidedSetup::PLATFORMS.keys)
      expect(inertia.props[:features].pluck(:key)).to eq(GuidedSetup::FEATURES.keys)
      expect(inertia.props[:scripts].pluck(:key)).to eq(['madani', 'indopak'])
      expect(inertia.props[:languages].pluck(:key)).to eq(GuidedSetup.languages.map(&:key))
      expect(inertia.props[:answers].symbolize_keys)
        .to eq(goals: [], platforms: [], features: [], scripts: [], languages: [], answered: [], step: 0)
      expect(inertia.props[:catalogPages]).to be(true)

      html = Nokogiri::HTML(response.body)
      expect(html.at('#app[data-server-rendered="true"]').text).to include('What are you building?')
      expect(html.at('title').text).to eq('Start building - QUL')
    end

    it 'gives each script the most downloaded Quran script of its family as a sample' do
      script = DownloadableResource.published.where(resource_type: 'quran-script').order(:id).first
      script.update_columns(script_family: 'indopak')
      get '/start'

      sample = inertia.props[:scripts].find { |option| option[:key] == 'indopak' }[:sample]
      indopak = Catalog::SearchQuery.new(Catalog::SearchFilters.from(type: 'quran-script', script: ['indopak'],
                                                                     sort: 'popular',)).call.results.first
      expect(sample).to include(id: indopak.resource.id, type: 'quran-script', previewKind: be_present)
    end

    # The query, the answers read from it and the step the flow opens at.
    [
      ['', {}, 0],
      ['goal=nope', {}, 0],
      ['goal[]=reader&goal[]=print', { goals: ['reader', 'print'], answered: ['goal'] }, 1],
      ['goal=reader&platform=mars', { goals: ['reader'], answered: ['goal'] }, 1],
      ['goal=reader&platform=&feature=nav', { goals: ['reader'], features: ['nav'],
                                              answered: ['goal', 'platform', 'feature'], }, 3,],
      ['goal=reader&platform=ios&feature=nav&script=other', { goals: ['reader'], platforms: ['ios'],
                                                              features: ['nav'],
                                                              answered: ['goal', 'platform', 'feature'], }, 3,],
      ['goal[x]=reader&script=madani&lang=en', { goals: ['reader'], scripts: ['madani'], languages: ['en'],
                                                 answered: ['goal', 'script', 'lang'], }, 1,],
      ['goal=reader&platform=ios&feature=nav&script=madani&lang=zz', { goals: ['reader'], platforms: ['ios'],
                                                                       features: ['nav'], scripts: ['madani'],
                                                                       answered: ['goal', 'platform', 'feature',
                                                                                  'script',], }, 4,],
      ['goal=reader&page[]=2&lang[a][b]=en&step=9', { goals: ['reader'], answered: ['goal'] }, 1],
    ].each do |query, expected, step|
      it "opens ?#{query} at step #{step + 1}" do
        get "/start?#{query}"

        expect(response).to have_http_status(:ok)
        empty = { goals: [], platforms: [], features: [], scripts: [], languages: [], answered: [] }
        expect(inertia.props[:answers].symbolize_keys).to eq(empty.merge(expected, step: step))
      end
    end

    it 'opens a complete setup at the last step, with the answers kept' do
      get "/start?#{complete}"

      expect(inertia.props[:answers].symbolize_keys).to eq(
        goals: ['reader'], platforms: ['ios', 'android'], features: ['mushaf', 'translation'], scripts: ['madani'],
        languages: ['en', 'ur'], answered: GuidedSetup::STEPS, step: 4,
      )
    end

    it 'ends on the catalog filtered for the answers: the needs checklist and its resources' do
      SsrServer.with_ssr { get "/resources?#{complete}" }

      expect(response).to have_http_status(:ok)
      expect(controller).to be_a(Start::SetupController)
      expect(inertia).to render_component('start/SetupResultsPage')
      props = inertia.props
      expect(props).to include(goals: ['Quran reader app'], platforms: ['iOS', 'Android'], formats: ['SQLite'],
                               editPath: "/start?#{complete.sub('android,ios', 'ios,android')}",)
      expect(props[:sections].pluck(:key)).to eq(['layout', 'font', 'text', 'translation-en', 'translation-ur'])
      expect(props[:sections].pluck(:label))
        .to eq(['Mushaf layout', 'Quran font', 'Quran text', 'Translation in English', 'Translation in Urdu'])

      urdu = props[:sections].last
      expect(urdu[:catalogPath]).to eq('/resources?granularity=1_ayah&language=ur&type=translation')
      search = Catalog::SearchQuery.new(Catalog::SearchFilters.from(type: 'translation', granularity: '1_ayah',
                                                                    language: 'ur',)).call
      expect(urdu[:total]).to eq(search.total)
      expect(urdu[:results].pluck(:id)).to eq(search.matches.first(Start::SetupController::CARDS)
        .map { |row| row.resource.id })
      expect(props[:total]).to be_between(props[:sections].pluck(:total).max, props[:sections].sum { |s| s[:total] })

      app = Nokogiri::HTML(response.body).at('#app[data-server-rendered="true"]')
      expect(app.text).to include('Filtered for your Quran reader app', 'Your app needs', 'Translation in Urdu')
    end

    it 'loads the catalog once, however many languages are picked' do
      loaded = ['en', 'en,ur,bn,ru,tr,id,fr,es'].map do |languages|
        count = 0
        counter = lambda do |*, payload|
          count += payload[:record_count] if payload[:class_name] == 'DownloadableResource'
        end
        ActiveSupport::Notifications.subscribed(counter, 'instantiation.active_record') do
          get "/resources?goal=study&feature=translation,tafsir,wbw&lang=#{languages}"
        end
        expect(inertia.props[:sections].size).to eq(3 * languages.split(',').size)
        count
      end

      expect(loaded.first).to be_positive
      expect(loaded.last).to eq(loaded.first)
    end

    it 'links each section to the catalog search that lists all of it' do
      get "/resources?#{complete}"
      section = inertia.props[:sections].find { |entry| entry[:key] == 'translation-en' }

      get section[:catalogPath]
      expect(inertia).to render_component('catalog/CatalogPage')
      expect(inertia.props[:total]).to eq(section[:total])
    end

    it 'fills in the features of partial answers from the goals' do
      get '/resources?goal=audio'

      expect(inertia.props[:sections].pluck(:key)).to eq(['text', 'recitation-timing', 'metadata'])
      expect(inertia.props[:editPath]).to eq('/start?goal=audio&platform=&feature=audio,highlight,nav&script=&lang=')
    end

    it 'sends answers without a known goal back to the first step' do
      get '/resources?goal=nope&script=madani'

      expect(response).to redirect_to('/start?goal=nope&script=madani')
    end

    it 'leaves the catalog without answers alone' do
      get '/resources?script=madani'

      expect(inertia).to render_component('catalog/CatalogPage')
    end
  end

  describe 'with the start group on and the catalog group off', page_groups: ['start'] do
    it 'serves the flow, without the results page' do
      get '/start?goal=reader'

      expect(inertia).to render_component('start/SetupPage')
      expect(inertia.props[:catalogPages]).to be(false)
      expect(inertia.props[:scripts].pluck(:sample)).to eq([nil, nil])

      get "/resources?#{complete}"
      expect(controller).to be_a(ResourcesController)
    end
  end

  describe 'with the start page group off', page_groups: ['home', 'catalog', 'apps', 'content'] do
    it 'is a 404, and the catalog ignores the answers' do
      get '/start'
      expect(response).to have_http_status(:not_found)

      get "/resources?#{complete}"
      expect(inertia).to render_component('catalog/CatalogPage')
    end

    it 'has no new page that links to it' do
      ['/', '/resources', '/resources/translation', '/apps', '/docs', '/faq'].each do |path|
        get path

        expect(response).to have_http_status(:ok), path
        expect(response.body).not_to match(%r{["']/start[?"']}), path
      end
    end
  end
end
