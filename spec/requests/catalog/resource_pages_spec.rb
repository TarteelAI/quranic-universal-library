require 'clone_helper'
require_relative '../../support/download_files'

RSpec.describe 'Resource detail pages (/resources/:type/:slug)', type: :request do
  include DownloadFiles
  include Devise::Test::IntegrationHelpers

  def page_path(resource, query = nil)
    ["/resources/#{resource.resource_type}/#{resource.to_param}", query].compact.join('?')
  end

  def props
    inertia.props.deep_symbolize_keys
  end

  def html
    Nokogiri::HTML(response.body)
  end

  # A published resource on a content row of its own, with two files: JSON and SQLite.
  let(:resource) { create_download_resource }
  let!(:json_file) { create_download_file(resource) }
  let!(:sqlite_file) do
    resource.downloadable_files.create!(name: 'spec.sqlite', file_type: 'simple.sqlite').tap do |file|
      file.file.attach(
        ActiveStorage::Blob.create!(key: "spec-downloads/#{SecureRandom.hex}", filename: 'spec.sqlite.zip',
                                    content_type: 'application/octet-stream', byte_size: 5_242_880,
                                    checksum: '1B2M2Y8AsgTpgAmY7PhCfg==', service_name: 'qul_exports',
                                    metadata: { identified: true, analyzed: true })
      )
    end
  end

  describe 'with the catalog page group on', page_groups: %w[catalog] do
    it 'renders every published resource on the clone with SSR, including the ones with data errors' do
      resources = DownloadableResource.published.where.not(id: resource.id).includes(:downloadable_files).to_a
      contents = ResourceContent.where(id: resources.map(&:resource_content_id)).index_by(&:id)
      layouts = resources.select(&:mushaf_layout?)
      mushafs = MushafLayouts::Page.mushafs_for(layouts)
      cases = {
        'no files' => resources.select { |r| r.downloadable_files.none?(&:published) },
        'unapproved content rows' => resources.select { |r| contents[r.resource_content_id]&.approved == false },
        'blank content names' => resources.select { |r| contents[r.resource_content_id]&.name.blank? },
        'no word rows' => layouts.select { |r| mushafs[r.id] && !MushafWord.exists?(mushaf_id: mushafs[r.id].id) }
      }
      cases.each { |name, rows| expect(rows).not_to be_empty, "no published resource with #{name} on the clone" }

      statuses = {}
      SsrServer.with_ssr do
        resources.each do |r|
          get page_path(r)
          statuses[r.id] = response.status
          expect(response.body).to include('data-server-rendered="true"'), "#{r.id} was not server-rendered"
        end
      end

      expect(statuses.values.tally).to eq(200 => resources.size)
      puts "\n    Swept #{resources.size} published resources: all 200 with SSR " \
           "(#{cases.map { |name, rows| "#{rows.size} with #{name}" }.join(', ')})"
      cases.each_value { |rows| expect(statuses.values_at(*rows.map(&:id))).to all(eq(200)) }
    end

    describe 'URLs' do
      it 'redirects an id URL and a wrong-type URL to the slug URL with a 301, keeping the query' do
        get "/resources/#{resource.resource_type}/#{resource.id}?tab=data"
        expect(response).to have_http_status(:moved_permanently)
        expect(response).to redirect_to("/resources/tafsir/#{resource.slug}?tab=data")

        get "/resources/translation/#{resource.slug}"
        expect(response).to have_http_status(:moved_permanently)
        expect(response).to redirect_to("/resources/tafsir/#{resource.slug}")
      end

      it 'redirects the old tab and copyright URLs to the page and the tab that holds what they showed' do
        { 'docs' => '?tab=data', 'licence' => '?tab=licence', 'ligatures' => '', 'glyphs' => '' }.each do |old, query|
          get "/resources/tafsir/#{resource.id}/#{old}"
          expect(response).to have_http_status(:moved_permanently)
          expect(response).to redirect_to("/resources/tafsir/#{resource.slug}#{query}")
        end

        get "/resources/#{resource.id}/copyright"
        expect(response).to redirect_to("/resources/tafsir/#{resource.slug}?tab=licence")
      end

      it 'serves a resource without a slug at its id URL' do
        resource.update_columns(slug: nil)

        get "/resources/tafsir/#{resource.id}"

        expect(response).to have_http_status(:ok)
        expect(inertia).to render_component('catalog/ResourcePage')
      end

      it 'downloads the file of a resource without a slug from its id URL', download_mode: 'public' do
        resource.update_columns(slug: nil)

        get "/resources/tafsir/#{resource.id}/download/#{json_file.id}"

        expect(response).to have_http_status(:found)
        expect(json_file.reload.anonymous_download_count).to eq(1)
      end

      it 'gives the 404 page for an unknown slug and for an unpublished resource' do
        get '/resources/tafsir/no-such-resource'
        expect(response).to have_http_status(:not_found)
        expect(inertia).to render_component('errors/ErrorPage')

        resource.update!(published: false)
        get "/resources/tafsir/#{resource.slug}"
        expect(response).to have_http_status(:not_found)
        expect(inertia).to render_component('errors/ErrorPage')
      end
    end

    it 'lists each file with its format label, stored byte size and MD5 checksum in hex' do
      get page_path(resource)

      expect(inertia).to render_component('catalog/ResourcePage')
      expect(props[:files]).to eq(
        [
          { id: json_file.id, name: 'json', format: 'json', formatLabel: 'JSON', byteSize: 1,
            md5: Base64.decode64('c3BlYw==').unpack1('H*') },
          { id: sqlite_file.id, name: 'simple.sqlite', format: 'sqlite', formatLabel: 'SQLite', byteSize: 5_242_880,
            md5: 'd41d8cd98f00b204e9800998ecf8427e' }
        ]
      )
      expect(props[:files].pluck(:byteSize)).to eq([json_file, sqlite_file].map { |f| f.file.blob.byte_size })
      expect(props).to include(canDownload: true, restriction: nil)
      expect(inertia).to have_deferred_props(:preview)
    end

    it 'says why a restricted resource cannot be downloaded, and lets only an admin download it' do
      restricted = create_download_resource(restricted: true)
      create_download_file(restricted)

      get page_path(restricted)
      expect(props).to include(canDownload: false)
      expect(props[:restriction]).to include('not downloaded')

      sign_in create_account
      get page_path(restricted)
      expect(props).to include(canDownload: false)

      sign_in create_account(role: :admin)
      get page_path(restricted)
      expect(props).to include(canDownload: true)
      expect(props[:restriction]).to be_present
    end

    it 'gives the copyright notice of a restricted resource as sanitized HTML' do
      restricted = create_download_resource(restricted: true)
      ResourcePermission.create!(resource_content_id: restricted.resource_content_id,
                                 copyright_notice: '<h5 style="margin:0">Notice</h5><script>x()</script>Ask first.')

      get page_path(restricted)

      expect(props[:restriction]).to eq('<h5>Notice</h5>x()Ask first.')
    end

    describe 'tabs' do
      it 'has no changelog for a resource without changelog rows, and says the licence is not yet confirmed' do
        get page_path(resource, 'tab=changelog')

        expect(props).to include(changelog: [], licence: nil, tab: 'preview')
      end

      it 'lists the published changelog entries, newest first, without their author' do
        author = create_account
        older = ChangeLog.create!(resource_content_id: resource.resource_content_id, user: author, title: 'First',
                                  text: '<p>First</p>', excerpt: 'First export', published: true,
                                  created_at: Time.zone.local(2026, 1, 2))
        newer = ChangeLog.create!(resource_content_id: resource.resource_content_id, user: author, title: 'Fixed',
                                  text: '<p>Fixed</p>', excerpt: 'Fixed a word', published: true,
                                  created_at: Time.zone.local(2026, 3, 4))
        ChangeLog.create!(resource_content_id: resource.resource_content_id, user: author, title: 'Draft',
                          text: 'Draft', excerpt: 'Draft', published: false)

        get page_path(resource, 'tab=changelog')

        expect(props[:tab]).to eq('changelog')
        expect(props[:changelog]).to eq(
          [
            { id: newer.id, title: 'Fixed', excerpt: 'Fixed a word', date: '4 March 2026', path: "/change_logs/#{newer.id}" },
            { id: older.id, title: 'First', excerpt: 'First export', date: '2 January 2026', path: "/change_logs/#{older.id}" }
          ]
        )
      end

      it 'opens the tab the query names' do
        %w[data licence preview].each do |tab|
          get page_path(resource, "tab=#{tab}")
          expect(props[:tab]).to eq(tab)
        end
        get page_path(resource, 'tab=nonsense')
        expect(props[:tab]).to eq('preview')
      end
    end

    it 'lists requires-links before pairs-with links, and marks a drafted link as not yet reviewed' do
      font = create_download_resource.tap { |r| r.update_columns(resource_type: 'font') }
      script = create_download_resource.tap { |r| r.update_columns(resource_type: 'quran-script') }
      layout = create_download_resource.tap { |r| r.update_columns(resource_type: 'mushaf-layout') }
      resource.downloadable_related_resources.create!(related_resource: script, relation_type: 'pairs_with')
      resource.downloadable_related_resources.create!(related_resource: font, relation_type: 'requires')
      layout.downloadable_related_resources.create!(related_resource: resource, relation_type: 'pairs_with')
      drafted = { "link:#{font.id}" => { 'value' => 'requires', 'by' => 'requires_links', 'at' => Time.current.iso8601 } }
      resource.update_columns(review: Catalog::Review.with_drafted(resource.review, drafted))

      get page_path(resource)

      groups = props[:worksWith]
      expect(groups.pluck(:key)).to eq(%w[requires pairs_with])
      expect(groups.first[:links]).to eq([{ reviewed: false, typeLabel: 'Font',
                                            resource: { id: font.id, toParam: font.to_param, name: font.name,
                                                        type: 'font' } }])
      expect(groups.second[:links].map { |link| [link[:resource][:id], link[:reviewed]] })
        .to eq([[script.id, true], [layout.id, true]])
    end

    describe 'the download sign-in returned for (?download=)' do
      it 'is started for a signed-in user' do
        sign_in create_account
        get page_path(resource, "download=#{sqlite_file.id}")

        expect(props).to include(download: sqlite_file.id, downloadMode: 'sign_in')
      end

      it 'is not started for an anonymous visitor in sign-in mode, nor for a file of another resource' do
        get page_path(resource, "download=#{sqlite_file.id}")
        expect(props[:download]).to be_nil

        sign_in create_account
        other = create_download_file(create_download_resource)
        get page_path(resource, "download=#{other.id}")
        expect(props[:download]).to be_nil
      end

      it 'is started for anyone in public mode', download_mode: 'public' do
        get page_path(resource, "download=#{json_file.id}")

        expect(props).to include(download: json_file.id, downloadMode: 'public')
      end
    end

    it 'has the head of the resource: title, description, canonical, Open Graph and Dataset JSON-LD' do
      resource.update_columns(short_summary: 'A spec tafsir in JSON and SQLite.')

      get page_path(resource, 'tab=data')

      url = "https://qul.tarteel.ai/resources/tafsir/#{resource.slug}"
      title = "#{resource.name} - Tafsir - QUL"
      expect(html.at('title').text).to eq(title)
      expect(html.at('meta[name="description"]')['content']).to eq('A spec tafsir in JSON and SQLite.')
      expect(html.at('link[rel="canonical"]')['href']).to eq(url)
      expect(html.at('meta[property="og:title"]')['content']).to eq(title)
      expect(html.at('meta[property="og:url"]')['content']).to eq(url)
      json_ld = JSON.parse(html.at('script[type="application/ld+json"]').text)
      expect(json_ld).to include('@type' => 'Dataset', 'name' => title, 'url' => url,
                                 'description' => 'A spec tafsir in JSON and SQLite.')
      expect(json_ld['distribution']).to eq(
        [{ '@type' => 'DataDownload', 'name' => 'json', 'encodingFormat' => 'JSON', 'contentSize' => 1 },
         { '@type' => 'DataDownload', 'name' => 'simple.sqlite', 'encodingFormat' => 'SQLite',
           'contentSize' => 5_242_880 }]
      )
    end

    # Every key of the page's own props, at any depth. A key outside this list fails the spec, so
    # a new prop is a decision: no data source, changelog author, download count or user field.
    allowed_keys = %i[
      resource type statuses files facts worksWith changelog licence tab downloadMode download issueUrl
      canDownload restriction updatedOn guidePath
      id name toParam status scriptFamily language granularity summary info recommendation reviewed
      supersededBy recommended rendering
      key label title description category
      format formatLabel byteSize md5 value links typeLabel url excerpt date path
    ]
    shared_keys = %i[auth nav errors flash head]

    def keys_of(value)
      case value
      when Hash then value.keys + value.values.flat_map { |v| keys_of(v) }
      when Array then value.flat_map { |v| keys_of(v) }
      else []
      end
    end

    it 'sends only allowed keys, with no data source, changelog author or user field' do
      author = create_account.tap { |user| user.update_columns(first_name: 'Changelog', last_name: 'Authorname') }
      ChangeLog.create!(resource_content_id: resource.resource_content_id, user: author, title: 'Fixed',
                        text: 'Fixed', excerpt: 'Fixed', published: true)
      resource.downloadable_related_resources.create!(related_resource: create_download_resource)
      sign_in create_account(role: :admin)

      get page_path(resource)

      own = props.except(*shared_keys)
      expect(keys_of(own).uniq - allowed_keys).to eq([])
      expect(own.to_json).not_to include(author.email, 'Authorname')
      expect(props.keys - own.keys).to match_array(shared_keys & props.keys)
    end

    it 'names the resource in the content issue form' do
      get page_path(resource)

      query = Rack::Utils.parse_query(URI(props[:issueUrl]).query)
      expect(props[:issueUrl]).to start_with('https://github.com/TarteelAI/quranic-universal-library/issues/new?')
      expect(query).to eq('template' => 'content_issue.yml', 'resource_type' => 'Tafsir', 'resource_name' => resource.name,
                          'resource_link' => "https://qul.tarteel.ai/resources/tafsir/#{resource.slug}")
    end

    it 'gives every resource type an option of the issue form dropdown' do
      form = YAML.load_file(Rails.root.join('.github/ISSUE_TEMPLATE/content_issue.yml'))
      options = form['body'].find { |field| field['id'] == 'resource_type' }.dig('attributes', 'options')

      expect(Catalog::Taxonomy::ISSUE_TYPES.keys).to match_array(DownloadableResource::RESOURCE_TYPES)
      expect(options).to include(*Catalog::Taxonomy::ISSUE_TYPES.values)
    end
  end

  describe 'with the catalog page group off', page_groups: [] do
    it 'leaves the detail URL to the old page' do
      get "/resources/tafsir/#{resource.id}"

      expect(controller).to be_a(ResourcesController)
    end
  end
end
