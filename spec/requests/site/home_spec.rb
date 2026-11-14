# frozen_string_literal: true

require 'clone_helper'

RSpec.describe 'Home page (/)', type: :request do
  def json_ld
    JSON.parse(Nokogiri::HTML(response.body).at('script[type="application/ld+json"]').text)
  end

  describe 'with the home page group on', page_groups: ['home', 'catalog', 'apps'] do
    it 'renders the Inertia home page, server-rendered' do
      SsrServer.with_ssr { get '/' }

      expect(response).to have_http_status(:ok)
      expect(controller).to be_a(Site::HomeController)
      expect(inertia).to render_component('site/HomePage')
      app = Nokogiri::HTML(response.body).at('#app[data-server-rendered="true"]')
      expect(app).to be_present
      expect(app.at('h1').text).to eq('Verified data for builders impacting the Ummah.')
      expect(app.at('canvas')).to be_present
      expect(app.css('dl dd').map(&:text)).to eq(inertia.props.values_at(:resources, :languages, :recitations)
                                                       .map { |count| count.to_fs(:delimited) })
    end

    it 'counts the published resources, their languages and the recitations as direct queries do' do
      get '/'

      cms = ApplicationRecord.connection
      content = QulQuranRecord.connection
      resources = cms.select_value('SELECT COUNT(*) FROM downloadable_resources WHERE published')
      recitations = cms.select_value(
        "SELECT COUNT(*) FROM downloadable_resources WHERE published AND resource_type = 'recitation'",
      )
      # A resource's language is its own row's, else its content row's.
      own = cms.select_values(
        'SELECT DISTINCT language_id FROM downloadable_resources WHERE published AND language_id IS NOT NULL',
      )
      unset = cms.select_values(<<~SQL.squish)
        SELECT DISTINCT resource_content_id FROM downloadable_resources
        WHERE published AND language_id IS NULL AND resource_content_id IS NOT NULL
      SQL
      languages = content.select_value(<<~SQL.squish)
        SELECT COUNT(DISTINCT languages.id) FROM languages
        WHERE languages.id IN (#{(own.map(&:to_i) + [0]).join(',')})
           OR languages.id IN (SELECT language_id FROM resource_contents WHERE id IN (#{(unset.map(&:to_i) + [0]).join(',')}))
      SQL

      expect(inertia.props).to include(resources: resources, recitations: recitations, languages: languages)
      expect([resources, recitations, languages]).to all(be_positive)
    end

    it 'counts each category of the taxonomy as the catalog facets do, with its hint and catalog link' do
      get '/'
      categories = inertia.props[:categories]

      get '/resources'
      facets = inertia.props[:facets][:category].to_h { |facet| [facet[:value], facet[:count]] }

      expect(categories.pluck(:key)).to eq(Catalog::Taxonomy::CATEGORIES.keys)
      categories.each do |category|
        taxonomy = Catalog::Taxonomy::CATEGORIES.fetch(category[:key])
        expect(category).to include(label: taxonomy.label, hint: taxonomy.hint)
        expect(category[:hint]).to be_present
        expect(category[:count]).to eq(facets.fetch(category[:key], 0)), category[:key]
      end
      expect(categories.sum { |category| category[:count] }).to eq(DownloadableResource.published.count)

      get '/resources?category=script'
      expect(inertia.props[:filters][:category]).to eq('script')
      expect(inertia.props[:total]).to eq(categories.find { |category| category[:key] == 'script' }[:count])
      expect(inertia.props[:results].pluck(:type).uniq - ['quran-script', 'font']).to be_empty
    end

    describe 'the data showcase' do
      let(:preview_props) { [:recitationPreview, :mushafLayoutPreview, :translationPreview, :morphologyPreview] }

      it 'holds one sample per tab, each a published resource of its type, with no preview in the first response' do
        get '/'

        samples = inertia.props[:samples]
        expect(samples.pluck(:type)).to eq(['recitation', 'mushaf-layout', 'translation', 'morphology'])
        samples.each do |sample|
          resource = Catalog::ResourcePage.find(sample[:toParam])
          expect(resource).to have_attributes(published: true, resource_type: sample[:type])
          expect(sample[:name]).to eq(resource.display_name)
          expect(sample[:count]).to eq(DownloadableResource.published.where(resource_type: sample[:type]).count)
        end
        expect(Catalog::ResourcePage.find(samples.first[:toParam]).cardinality_type).to eq('1_chapter')
        expect(inertia.props.keys.map(&:to_sym)).not_to include(*preview_props)
        expect(inertia.deferred_props).to be_empty
      end

      it "loads each tab's preview on its own, the detail page's preview of the sample" do
        get '/'
        samples = inertia.props[:samples].index_by { |sample| sample[:type] }

        { recitationPreview: ['recitation', 'recitation'], mushafLayoutPreview: ['mushaf-layout', 'layout'],
          translationPreview: ['translation', 'text'], morphologyPreview: ['morphology', 'records'], }
          .each do |prop, (type, kind)|
          inertia_reload_only(prop)
          expect(inertia.props.keys.map(&:to_sym) - [:errors, :head]).to eq([prop])
          expect(inertia.props[prop]).to include(kind: kind)
          # The recitation's Al-Fatihah has segment data, so the player highlights each ayah.
          expect(inertia.props[prop][:highlights]).to be(true) if type == 'recitation'

          resource = Catalog::ResourcePage.find(samples.fetch(type)[:toParam])
          expected = JSON.parse(Previews.as_json(Previews.for(resource)).to_json)
          expect(inertia.props[prop].as_json).to eq(expected)
        end
      end

      it 'leaves out a tab whose type has no published resource, and still renders the page' do
        DownloadableResource.where(resource_type: 'morphology').update_all(published: false)

        SsrServer.with_ssr { get '/' }

        expect(response).to have_http_status(:ok)
        expect(inertia.props[:samples].pluck(:type)).to eq(['recitation', 'mushaf-layout', 'translation'])
        inertia_reload_only(:morphologyPreview)
        expect(inertia.props[:morphologyPreview]).to be_nil
      end

      it 'renders the open tab on the server without its preview, and no other tab' do
        SsrServer.with_ssr { get '/' }

        app = Nokogiri::HTML(response.body).at('#app[data-server-rendered="true"]')
        tabs = app.css('[role="tab"]')
        expect(tabs.map(&:text)).to eq(['Recitations', 'Mushaf layouts', 'Translations', 'Morphology'])
        panels = app.css('[role="tabpanel"]')
        expect(panels.count { |panel| !panel['hidden'] }).to eq(1)
        expect(panels.select { |panel| panel['hidden'] }.map(&:inner_html)).to all(be_empty)
        expect(app.at('audio, [data-testid="no-preview"]')).to be_nil
      end
    end

    it 'shows three contribution tools and links the tools overview' do
      get '/'

      expect(inertia.props[:tools].pluck(:label))
        .to eq(['Ayah translations', 'Ayah audio segments', 'Word grammar and morphology'])
      tools = controller.helpers.developer_tools.index_by(&:title)
      inertia.props[:tools].each do |tool|
        expect(tool).to include(href: tools.fetch(tool[:label]).url, inertia: false)
        expect(tool[:icon]).to be_present
        expect(tool[:description]).to be_present
      end
      expect(inertia.props).to include(contentPages: false)
    end

    it 'shows the first eight published apps of the directory in the apps band, and no submission' do
      AppDirectory::Import.run
      submission = App.create!(name: 'Spec Unpublished Submission', url: 'https://example.test/app',
                               platforms: ['web'], uses: ['translation'], featured: true,)
      get '/'

      # The band of sprint 001, from the import.
      showcase = ['quranwbw', 'qurancaption', 'quran-library', 'quran-validator', 'mihrab', 'bayaan', 'al-quran-ios',
                  'quranic-universal-audio',].map do |key|
        App.find_by!(import_key: key).id.to_s
      end
      expect(inertia.props[:showcase].pluck(:id)).to eq(showcase)
      expect(inertia.props[:showcase].pluck(:id)).not_to include(submission.id.to_s)
      expect(inertia.props).to include(appsCount: App.where(published: true).count, appsPage: true,
                                       catalogPages: true,)
      expect(inertia.props).not_to have_key(:submitUrl)
      expect(response.body).not_to include('Spec Unpublished Submission')
    end

    it 'keeps the old landing page title and description, and its WebSite and Organization JSON-LD' do
      ENV['QUL_PAGE_GROUPS'] = ''
      get '/'
      expect(controller).to be_a(LandingController)
      old_html = Nokogiri::HTML(response.body)
      old_json_ld = json_ld

      ENV['QUL_PAGE_GROUPS'] = 'home'
      get '/'
      expect(controller).to be_a(Site::HomeController)
      html = Nokogiri::HTML(response.body)
      ['title'].each { |tag| expect(html.at(tag).text).to eq(old_html.at(tag).text) }
      ['meta[name="description"]', 'meta[property="og:title"]', 'meta[property="og:description"]',
       'meta[name="twitter:card"]',].each do |selector|
        expect(html.at(selector)['content']).to eq(old_html.at(selector)['content']), selector
      end
      expect(html.at('link[rel="canonical"]')['href']).to eq('https://qul.tarteel.ai/')
      expect(html.at('meta[property="og:url"]')['content']).to eq('https://qul.tarteel.ai/')
      expect(html.at('meta[property="og:image"]')['content']).to eq(old_html.at('meta[property="og:image"]')['content'])

      expect(json_ld['@type']).to eq(old_json_ld['@type']).and eq('WebSite')
      expect(json_ld['publisher']['@type']).to eq(old_json_ld['publisher']['@type']).and eq('Organization')
      expect(json_ld.slice('name', 'alternateName', 'url', 'publisher'))
        .to eq(old_json_ld.slice('name', 'alternateName', 'url', 'publisher'))
    end

    it 'gives the header a home link that is an Inertia visit, and links the apps directory' do
      get '/'

      nav = inertia.props[:nav]
      expect(nav[:home]).to include(href: '/', inertia: true)
      community = nav[:footer].find { |group| group[:heading] == 'Community' }[:links]
      expect(community.first).to include(label: 'Apps built with QUL', href: '/apps', inertia: true)
    end
  end

  describe 'with the home page group on and the others off', page_groups: ['home'] do
    it 'links the catalog as old pages and leaves out the apps directory' do
      get '/'

      expect(inertia.props).to include(catalogPages: false, appsPage: false)
      footer_links = inertia.props[:nav][:footer].flat_map { |group| group[:links] }
      expect(footer_links.pluck(:href)).not_to include('/apps')
    end
  end

  describe 'with the home page group off', page_groups: ['catalog', 'apps'] do
    it 'renders the old landing page' do
      get '/'

      expect(response).to have_http_status(:ok)
      expect(controller).to be_a(LandingController)
      expect(response.body).not_to include('data-page="app"')
      expect(response.body).to include('The Toolkit for Muslim Developers')
    end

    it 'makes the header home link a plain link from the new pages' do
      get '/resources'

      expect(inertia.props[:nav][:home]).to include(href: '/', inertia: false)
    end
  end
end
