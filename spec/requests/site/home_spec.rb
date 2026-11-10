require 'clone_helper'

RSpec.describe 'Home page (/)', type: :request do
  def json_ld
    JSON.parse(Nokogiri::HTML(response.body).at('script[type="application/ld+json"]').text)
  end

  describe 'with the home page group on', page_groups: %w[home catalog apps] do
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
        "SELECT COUNT(*) FROM downloadable_resources WHERE published AND resource_type = 'recitation'"
      )
      # A resource's language is its own row's, else its content row's.
      own = cms.select_values(
        'SELECT DISTINCT language_id FROM downloadable_resources WHERE published AND language_id IS NOT NULL'
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

    it 'counts each category and type of the taxonomy' do
      get '/'

      categories = inertia.props[:categories]
      expect(categories.pluck(:key)).to eq(Catalog::Taxonomy::CATEGORIES.keys)
      expect(categories.flat_map { |category| category[:types].pluck(:key) })
        .to match_array(Catalog::Taxonomy.types.map(&:key))
      published = DownloadableResource.published.group(:resource_type).count
      categories.each do |category|
        category[:types].each { |type| expect(type[:count]).to eq(published.fetch(type[:key], 0)), type[:key] }
        expect(category[:count]).to eq(category[:types].sum { |type| type[:count] })
      end
      expect(categories.sum { |category| category[:count] }).to eq(inertia.props[:resources])
    end

    it 'shows the apps of the showcase, in the order of the data file' do
      get '/'

      expect(inertia.props[:showcase].pluck(:id)).to eq(AppDirectory.data.fetch('showcase'))
      expect(inertia.props).to include(appsCount: AppDirectory.apps.size, appsPage: true, catalogPages: true,
                                       submitUrl: AppDirectory::SUBMIT_URL)
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
      %w[title].each { |tag| expect(html.at(tag).text).to eq(old_html.at(tag).text) }
      %w[meta[name="description"] meta[property="og:title"] meta[property="og:description"]
         meta[name="twitter:card"]].each do |selector|
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

  describe 'with the home page group on and the others off', page_groups: %w[home] do
    it 'links the catalog as old pages and leaves out the apps directory' do
      get '/'

      expect(inertia.props).to include(catalogPages: false, appsPage: false)
      footer_links = inertia.props[:nav][:footer].flat_map { |group| group[:links] }
      expect(footer_links.pluck(:href)).not_to include('/apps')
    end
  end

  describe 'with the home page group off', page_groups: %w[catalog apps] do
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
