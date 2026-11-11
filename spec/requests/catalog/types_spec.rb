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

    it 'gives each of the 14 types its own title, description and JSON-LD' do
      heads = types.map do |type|
        get "/resources/#{type}"

        html = Nokogiri::HTML(response.body)
        taxonomy = Catalog::Taxonomy.type(type)
        title = html.at('title').text
        description = html.at('meta[name="description"]')['content']
        json_ld = JSON.parse(html.at('script[type="application/ld+json"]').text)
        expect(title).to eq("#{taxonomy.title} - QUL")
        expect(description).to eq(taxonomy.description)
        expect(json_ld).to include('@type' => 'CollectionPage', 'name' => title,
                                   'url' => "https://qul.tarteel.ai/resources/#{type}")
        [title, description, json_ld]
      end

      expect(heads.map(&:first).uniq.size).to eq(14)
      expect(heads.map(&:second).uniq.size).to eq(14)
      expect(heads.map(&:third).uniq.size).to eq(14)
    end

    it 'shows no "Which one should I pick?" block for a type with no status data beyond the default' do
      resources = DownloadableResource.published.where(resource_type: 'translation')
      expect(resources.where.not(status: 'stable').or(resources.where(recommended: true))).to be_empty

      get '/resources/translation'

      expect(inertia.props[:pick]).to be_nil
      expect(inertia.props[:comparison]).to be_nil
    end

    it 'shows the block on a type where one resource is legacy, and a superseded card links to its replacement' do
      old, replacement = DownloadableResource.published.where(resource_type: 'transliteration').order(:id).first(2)
      old.update_columns(status: 'superseded', superseded_by_id: replacement.id)

      get '/resources/transliteration'

      expect(inertia.props[:pick]).to eq(Catalog::Taxonomy::PICK_DEFAULT)
      card = inertia.props[:resources].find { |c| c[:id] == old.id }
      expect(card).to include(status: 'superseded', supersededBy: include(id: replacement.id,
                                                                         toParam: replacement.to_param))
      expect(inertia.props[:statuses].pluck(:key)).to eq(%w[stable beta legacy superseded])
    end

    it 'marks a drafted recommendation as not yet reviewed, and not once a person has reviewed it' do
      layout = DownloadableResource.published.where(resource_type: 'mushaf-layout').order(:id).first
      drafted = { 'recommended' => { 'value' => true, 'by' => 'recommended', 'at' => Time.current.utc.iso8601 } }
      layout.update_columns(recommended: true, review: Catalog::Review.with_drafted(layout.review, drafted))

      get '/resources/mushaf-layout'

      expect(inertia.props[:resources].find { |c| c[:id] == layout.id }).to include(recommendation: 'drafted')
      expect(inertia.props[:pick]).to eq(Catalog::Taxonomy::PICKS.fetch('mushaf-layout'))

      layout.reload.mark_reviewed!('recommended')
      get '/resources/mushaf-layout'

      expect(inertia.props[:resources].find { |c| c[:id] == layout.id }).to include(recommendation: 'reviewed')
      expect(inertia.props[:resources].pluck(:recommendation).compact).to eq(['reviewed'])
    end

    it "compares every published layout with its mushaf's page count and lines per page" do
      get '/resources/mushaf-layout'

      comparison = inertia.props[:comparison]
      expect(comparison[:columns].pluck(:key)).to eq(%w[script_family pages lines_per_page rendering font status])
      layouts = DownloadableResource.published.where(resource_type: 'mushaf-layout')
      expect(comparison[:rows].pluck(:id)).to match_array(layouts.ids)

      # The mushaf of each layout, straight from the content database: the `mushaf` meta key, else
      # the enabled mushaf with the lowest id on the layout's content row.
      expected = layouts.to_h do |layout|
        mushaf_id = QulQuranRecord.connection.select_value(<<~SQL.squish)
          SELECT m.id FROM resource_contents rc
          JOIN mushafs m ON m.id::text = NULLIF(rc.meta_data->>'mushaf', '')
             OR (NULLIF(rc.meta_data->>'mushaf', '') IS NULL AND m.resource_content_id = rc.id)
          WHERE rc.id = #{layout.resource_content_id.to_i}
          ORDER BY m.enabled DESC, m.id ASC LIMIT 1
        SQL
        mushaf = QulQuranRecord.connection.select_one(
          "SELECT pages_count, lines_per_page FROM mushafs WHERE id = #{mushaf_id.to_i}"
        )
        [layout.id, { 'pages' => mushaf&.fetch('pages_count'), 'linesPerPage' => mushaf&.fetch('lines_per_page') }]
      end
      expect(comparison[:rows].to_h { |row| [row[:id], row.slice(:pages, :linesPerPage)] }).to eq(expected)
      expect(expected.values.pluck('pages')).to all(be_positive)

      # One layout's mushaf has more page rows than pages; the table shows the page count.
      page_rows = MushafPage.group(:mushaf_id).count
      over = layouts.select do |layout|
        mushaf = MushafLayouts::Page.mushaf_for(layout)
        mushaf && page_rows.fetch(mushaf.id, 0) > mushaf.pages_count
      end
      expect(over).not_to be_empty
      over.each do |layout|
        row = comparison[:rows].find { |r| r[:id] == layout.id }
        expect(row[:pages]).to eq(MushafLayouts::Page.mushaf_for(layout).pages_count)
      end
    end

    it 'names the font a layout requires, when that font is published' do
      layout = DownloadableResource.published.where(resource_type: 'mushaf-layout').order(:id).first
      font = DownloadableResource.published.where(resource_type: 'font').order(:id).first
      DownloadableRelatedResource.where(downloadable_resource: layout).delete_all
      link = DownloadableRelatedResource.create!(downloadable_resource: layout, related_resource: font,
                                                 relation_type: 'requires')

      get '/resources/mushaf-layout'

      row = inertia.props[:comparison][:rows].find { |r| r[:id] == link.downloadable_resource_id }
      expect(row[:font]).to include(id: link.related_resource_id)
    end

    it 'has a comparison table for scripts and fonts too, without layout facts' do
      %w[quran-script font].each do |type|
        get "/resources/#{type}"

        rows = inertia.props[:comparison][:rows]
        expect(rows.pluck(:id)).to match_array(DownloadableResource.published.where(resource_type: type).ids)
        expect(rows.pluck(:pages, :linesPerPage).flatten).to all(be_nil)
      end
    end

    it "links each type to its format guide, the same page the detail page's Data tab links to" do
      get '/resources/mushaf-layout'
      expect(inertia.props[:guidePath]).to eq('/docs/resource-mushaf-layouts')

      types.each do |type|
        get "/resources/#{type}"
        guide = Catalog::Taxonomy::GUIDES[type]
        expect(inertia.props[:guidePath]).to eq(guide && "/docs/#{guide}"), type
      end
    end

    it 'sends no guide for a type without one' do
      stub_const('Catalog::Taxonomy::GUIDES', Catalog::Taxonomy::GUIDES.except('ayah-theme'))
      get '/resources/ayah-theme'

      expect(inertia.props[:guidePath]).to be_nil
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
        name: resource.display_name,
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
      tafsirs = DownloadableResource.published.where(resource_type: 'tafsir')
      expect(card_names).to match_array(tafsirs.map(&:display_name))

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
