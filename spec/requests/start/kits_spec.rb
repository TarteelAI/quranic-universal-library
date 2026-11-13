# frozen_string_literal: true

require 'clone_helper'

# The starter kits (/kits, /kits/:key) and the ways into the guided setup from the home page and
# the header. The test clone has no catalog backfill, which gives every resource the slug a kit
# names it by, so each example runs it first, as production will have.
RSpec.describe 'Starter kits (/kits)', type: :request do
  before { Catalog::Backfill.run }

  let(:kit) { Kits.find('indopak-urdu') }

  def props
    inertia.props.deep_symbolize_keys
  end

  describe 'with the start, catalog and home page groups on', page_groups: ['start', 'catalog', 'home', 'apps'] do
    it 'renders the kits index with a card for each kit, server-rendered' do
      SsrServer.with_ssr { get '/kits' }

      expect(response).to have_http_status(:ok)
      expect(inertia).to render_component('start/KitsPage')
      expect(props[:kits].pluck(:key)).to eq(Kits.all.map(&:key))
      card = props[:kits].find { |entry| entry[:key] == kit.key }
      expect(card).to include(title: kit.title, tag: kit.tag, blurb: kit.blurb, path: '/kits/indopak-urdu')
      names = DownloadableResource.where(slug: kit.items.map(&:resource)).index_by(&:slug)
      expect(card[:resources]).to eq(kit.items.map do |item|
        resource = names.fetch(item.resource)
        { name: resource.display_name, category: Catalog::Taxonomy.type(resource.resource_type).category.key }
      end)

      html = Nokogiri::HTML(response.body)
      expect(html.at('#app[data-server-rendered="true"]').text).to include('Starter kits', kit.title)
      expect(html.at('title').text).to eq('Starter kits - QUL')
      expect(html.at('meta[name="description"]')['content']).to start_with('Curated sets of Quran data')
    end

    it 'renders a kit page with each item, its reason and its alternative, server-rendered' do
      SsrServer.with_ssr { get '/kits/indopak-urdu' }

      expect(response).to have_http_status(:ok)
      expect(inertia).to render_component('start/KitPage')
      expect(props).to include(key: 'indopak-urdu', title: kit.title, description: kit.description,
                               kitsPath: '/kits', platforms: ['iOS', 'Android'], formats: ['SQLite'],
                               catalogPages: true,)
      expect(props[:items].map { |item| [item[:need], item[:resource][:toParam], item[:alternative]&.dig(:toParam)] })
        .to eq(kit.items.map { |item| [item.need, item.resource, item.alternative] })
      expect(props[:items].pluck(:why)).to eq(kit.items.map(&:why))
      expect(props[:items].first[:resource]).to include(type: 'mushaf-layout', formats: be_present)

      html = Nokogiri::HTML(response.body)
      text = html.at('#app[data-server-rendered="true"]').text
      expect(text).to include(kit.title, 'Why: ', 'Swap for')
      expect(html.at('title').text).to eq("#{kit.title} - Starter kits - QUL")
      expect(html.at('meta[name="description"]')['content']).to eq(kit.blurb)
    end

    it "opens the guided setup with the kit's answers from the kit page" do
      get '/kits/indopak-urdu'
      get props[:setupPath]

      expect(inertia).to render_component('start/SetupPage')
      expect(props[:answers]).to include(goals: ['reader'], platforms: ['ios', 'android'], scripts: ['indopak'],
                                         languages: ['ur', 'en'], answered: GuidedSetup::STEPS, step: 4,)
    end

    it 'leaves out an item whose resource is unpublished, and an unpublished alternative' do
      DownloadableResource.where(slug: kit.items.first.resource).update_all(published: false)
      DownloadableResource.where(slug: kit.items.last.alternative).update_all(published: false)
      get '/kits/indopak-urdu'

      expect(response).to have_http_status(:ok)
      expect(props[:items].pluck(:need)).to eq(kit.items.drop(1).map(&:need))
      expect(props[:items].last[:alternative]).to be_nil

      get '/kits'
      card = props[:kits].find { |entry| entry[:key] == kit.key }
      expect(card[:resources].size).to eq(kit.items.size - 1)
    end

    it 'is a 404 for a key no kit has' do
      get '/kits/no-such-kit'

      expect(response).to have_http_status(:not_found)
      expect(inertia).to render_component('errors/ErrorPage')
    end

    it "gives the home page the setup's goals and the first three kits" do
      get '/'

      expect(props[:startPages]).to be(true)
      expect(props[:goals].pluck(:key)).to eq(GuidedSetup::GOALS.keys)
      expect(props[:kits].pluck(:path)).to eq(Kits.all.first(3).map { |entry| "/kits/#{entry.key}" })
    end

    it 'puts the Start building menu first in the header, with a link per goal and the kits' do
      get '/resources'
      menu = props[:nav][:menus].first

      expect(menu).to include(label: 'Start building', href: '/start', inertia: true)
      expect(menu[:groups].first[:links].pluck(:href)).to eq(GuidedSetup::GOALS.keys.map { |key| "/start?goal=#{key}" })
      expect(menu[:groups].first[:links].pluck(:label)).to eq(GuidedSetup::GOALS.values.map(&:label))
      expect(menu[:aside].first[:links].map { |link| link.values_at(:label, :href, :inertia) }).to eq(
        [['Guided setup', '/start', true], ['Starter kits', '/kits', true], ['Apps built with QUL', '/apps', true]],
      )
    end
  end

  describe 'with the start group on and the catalog group off', page_groups: ['start'] do
    it 'serves the kit page, its cards linking the old detail pages' do
      get '/kits/indopak-urdu'

      expect(inertia).to render_component('start/KitPage')
      expect(props[:catalogPages]).to be(false)
      expect(props[:items].size).to eq(kit.items.size)
    end
  end

  describe 'with the start page group off', page_groups: ['home', 'catalog', 'apps', 'content'] do
    it 'is a 404' do
      ['/kits', '/kits/indopak-urdu'].each do |path|
        get path

        expect(response).to have_http_status(:not_found), path
      end
    end

    it 'gives the home page no goals, kits or setup buttons, and the header no Start building menu' do
      get '/'

      expect(props).to include(startPages: false, goals: [], kits: [])
      expect(props[:nav][:menus].pluck(:label)).to eq(['Resources', 'Docs', 'Developers', 'Contribute'])
      expect(response.body).not_to match(%r{["']/kits[/"']})
    end
  end
end
