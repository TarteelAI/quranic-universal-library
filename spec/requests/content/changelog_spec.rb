# frozen_string_literal: true

require 'clone_helper'
require_relative '../../support/download_files'

RSpec.describe 'The changelog (/changelog, /changelog/:id)', type: :request do
  include DownloadFiles

  let(:author) { create_account }

  def create_entry(resource_content_id:, title: 'Fixed', text: '<p>Fixed a word.</p>', published: true,
                   created_at: 1.day.from_now)
    ChangeLog.create!(resource_content_id:, user: author, title:, text:, excerpt: "#{title} excerpt",
                      published:, created_at:,)
  end

  def newest_first
    ChangeLog.published.order(created_at: :desc, id: :desc).pluck(:id)
  end

  describe 'with the content page group on', page_groups: ['content'] do
    it 'lists the published entries, newest first, a page at a time, server-rendered' do
      resource = create_download_resource
      newest = create_entry(resource_content_id: resource.resource_content_id, title: 'Newest')
      create_entry(resource_content_id: resource.resource_content_id, title: 'Draft', published: false)
      per_page = Content::Changelog::PER_PAGE
      ids = newest_first
      expect(ids.size).to be > per_page

      SsrServer.with_ssr { get '/changelog' }

      expect(response).to have_http_status(:ok)
      expect(controller).to be_a(Content::ChangelogController)
      expect(inertia).to render_component('content/ChangelogPage')
      expect(inertia.props[:entries].pluck(:id)).to eq(ids.first(per_page))
      expect(inertia.props).to include(page: 1, pages: (ids.size / per_page.to_f).ceil)
      expect(inertia.props[:entries].first.deep_symbolize_keys).to eq(
        id: newest.id, title: 'Newest', excerpt: 'Newest excerpt', date: newest.created_at.strftime('%-d %B %Y'),
        path: "/changelog/#{newest.id}",
        resource: { name: resource.resource_content.name,
                    path: "/resources/#{resource.resource_type}/#{resource.to_param}", },
      )
      expect(inertia.props[:entries].pluck(:title)).not_to include('Draft')
      app = Nokogiri::HTML(response.body).at('#app[data-server-rendered="true"]')
      expect(app.css("a[href='/changelog/#{newest.id}']")).to be_present

      get '/changelog', params: { page: 2 }

      expect(inertia.props[:entries].pluck(:id)).to eq(ids.drop(per_page).first(per_page))
      expect(inertia.props[:page]).to eq(2)
    end

    it 'answers 404 for a page out of range or not a number' do
      pages = (newest_first.size / Content::Changelog::PER_PAGE.to_f).ceil

      [(pages + 1).to_s, '0', '-1', 'two', '1.5'].each do |page|
        get '/changelog', params: { page: page }

        expect(response).to have_http_status(:not_found), page
        expect(inertia).to render_component('errors/ErrorPage'), page
      end
      get '/changelog?page[]=1'
      expect(response).to have_http_status(:not_found)
    end

    it 'shows an entry with its date and body, linking to its published resource' do
      resource = create_download_resource
      entry = create_entry(resource_content_id: resource.resource_content_id, text: '<ul><li><p>Fixed</p></li></ul>')

      SsrServer.with_ssr { get "/changelog/#{entry.id}" }

      expect(response).to have_http_status(:ok)
      expect(inertia).to render_component('content/ChangelogEntryPage')
      expect(inertia.props[:entry].deep_symbolize_keys).to eq(
        id: entry.id, title: 'Fixed', date: entry.created_at.strftime('%-d %B %Y'),
        body: '<ul><li><p>Fixed</p></li></ul>',
        resource: { name: resource.resource_content.name,
                    path: "/resources/#{resource.resource_type}/#{resource.to_param}", },
      )
      app = Nokogiri::HTML(response.body).at('#app[data-server-rendered="true"]')
      expect(app.css("a[href='/resources/#{resource.resource_type}/#{resource.to_param}']")).to be_present
      expect(Nokogiri::HTML(response.body).at('title').text).to eq('Fixed - Changelog - QUL')
    end

    it 'names the resource of an entry without a link while the resource is not published' do
      resource = create_download_resource(published: false)
      entry = create_entry(resource_content_id: resource.resource_content_id)

      get "/changelog/#{entry.id}"

      expect(inertia.props[:entry][:resource].deep_symbolize_keys)
        .to eq(name: resource.resource_content.name, path: nil)
    end

    it 'answers 404 for an unpublished or unknown entry' do
      draft = create_entry(resource_content_id: create_download_resource.resource_content_id, published: false)

      [draft.id, 0].each do |id|
        get "/changelog/#{id}"

        expect(response).to have_http_status(:not_found), id.to_s
      end
    end

    it 'reduces an entry body with editor markup to formatted text' do
      hostile = '<p onclick="steal()">Read <a href="javascript:alert(1)" onmouseover="x()">this</a> and ' \
                '<a href="https://example.com/x" target="_blank">that</a>.</p><script>alert(1)</script>' \
                '<img src="x" onerror="alert(2)"><iframe src="https://example.com"></iframe><strong>kept</strong>'
      entry = create_entry(resource_content_id: create_download_resource.resource_content_id, text: hostile)

      get "/changelog/#{entry.id}"

      fragment = Nokogiri::HTML5.fragment(inertia.props[:entry][:body])
      expect(fragment.css('script, img, iframe')).to be_empty
      expect(fragment.xpath('.//@*').map { |attribute| [attribute.name, attribute.value] })
        .to eq([['href', 'https://example.com/x']])
      expect(fragment.text).to eq('Read this and that.kept')
    end

    it 'redirects the old URLs permanently, keeping the page' do
      get '/change_logs'
      expect(response).to redirect_to('/changelog')
      expect(response).to have_http_status(:moved_permanently)

      get '/change_logs?page=2'
      expect(response).to redirect_to('/changelog?page=2')

      get '/change_logs/31'
      expect(response).to redirect_to('/changelog/31')
      expect(response).to have_http_status(:moved_permanently)
    end
  end

  describe 'with the catalog and content page groups on', page_groups: ['catalog', 'content'] do
    it "links the detail page's Changelog tab to the new entry pages" do
      resource = create_download_resource
      entry = create_entry(resource_content_id: resource.resource_content_id)

      get "/resources/#{resource.resource_type}/#{resource.to_param}?tab=changelog"

      expect(inertia.props[:changelog].pluck(:path)).to eq(["/changelog/#{entry.id}"])
    end
  end

  describe 'with the content page group off', page_groups: [] do
    it 'serves the old pages at the old URLs' do
      id = newest_first.first

      ['/change_logs', "/change_logs/#{id}"].each do |path|
        get path

        expect(response).to have_http_status(:ok), path
        expect(controller).to be_a(ChangeLogsController), path
        expect(response.body).not_to include('data-page='), path
      end
    end
  end
end
