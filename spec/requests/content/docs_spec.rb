require 'clone_helper'

RSpec.describe 'Docs pages (/docs/:key)', type: :request do
  # One tutorial with a runnable example, one resource guide, one tag page.
  let(:tutorial) { 'tutorial-recitation-end-to-end' }
  let(:guide) { 'resource-translations' }
  let(:tag) { 'murattal' }
  let(:html_page) { { 'Accept' => 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8' } }

  def with_page_groups(groups)
    original = ENV.fetch('QUL_PAGE_GROUPS', nil)
    ENV['QUL_PAGE_GROUPS'] = groups.join(',')
    yield
  ensure
    ENV['QUL_PAGE_GROUPS'] = original
  end

  def headings(html, article)
    Nokogiri::HTML(html).at(article)
            .xpath('.//*[self::h1 or self::h2 or self::h3 or self::h4 or self::h5 or self::h6]')
            .map { |heading| heading.text.squish }
  end

  def old_headings(key)
    with_page_groups([]) { get "/docs/#{key}", headers: html_page }
    expect(controller).to be_a(CommunityController)
    headings(response.body, 'article.tw-docs')
  end

  describe 'with the content page group on', page_groups: %w[content catalog] do
    it 'server-renders the tutorial, the resource guide and the tag page with the old headings, in order' do
      [tutorial, guide, tag].each do |key|
        expected = old_headings(key)
        SsrServer.with_ssr { get "/docs/#{key}", headers: html_page }

        expect(response).to have_http_status(:ok)
        expect(controller).to be_a(Content::DocsController)
        expect(inertia).to render_component('content/DocsPage')
        expect(expected).not_to be_empty
        expect(headings(response.body, '#app[data-server-rendered="true"] article')).to eq(expected), key
      end
    end

    it 'sends a markdown page as segments, its contents list and its place in the manifest' do
      get "/docs/#{tutorial}", headers: html_page

      doc = inertia.props[:doc]
      expect(doc).to include(key: tutorial, kind: 'page', title: DocsPageService.new.find(tutorial).title)
      kinds = doc[:segments].pluck(:kind)
      expect(kinds).to include('html', 'code', 'playground')
      playground = doc[:segments].find { |segment| segment[:kind] == 'playground' }
      expect(playground[:code]).to include('const words = [', 'setActiveWord(currentSecond);')
      code = doc[:segments].find { |segment| segment[:kind] == 'code' }
      expect(code[:code]).to be_present
      expect(code[:label]).to be_present

      prose = doc[:segments].filter_map { |segment| segment[:html] }.join
      expect(prose).not_to match(/<(button|textarea|iframe|script|div)\b|\sdata-[\w-]+=/)
      ids = Nokogiri::HTML5.fragment(prose).css('h2, h3').map { |heading| heading['id'] }
      expect(doc[:contents].pluck(:id)).to eq(ids)
      expect(ids.uniq).to eq(ids)
      expect(doc[:contents].pluck(:level)).to include(2).and all(be_in([2, 3]))

      expect(doc[:position].to_h.deep_symbolize_keys).to eq(
        category: { key: 'download-resources', title: 'Download Resources' },
        previous: { key: 'tutorials', title: 'Tutorials' },
        next: { key: 'tutorial-mushaf-layout-end-to-end', title: 'Mushaf Layout' }
      )
    end

    it 'gives a page the manifest does not list no place in it' do
      get "/docs/#{guide}", headers: html_page

      expect(inertia.props[:doc][:kind]).to eq('page')
      expect(inertia.props[:doc][:position].to_h.deep_symbolize_keys).to eq(category: nil, previous: nil, next: nil)
    end

    it 'lists the published resources of a tag page as links to their detail pages' do
      record = DownloadableResourceTag.find_by!(slug: tag)
      get "/docs/#{tag}", headers: html_page

      doc = inertia.props[:doc]
      expect(doc).to include(kind: 'tag', title: record.name)
      expect(doc[:position].values).to all(be_nil)
      links = Nokogiri::HTML5.fragment(doc[:segments].pluck(:html).join).css('li a').map { |link| link['href'] }
      published = record.downloadable_resources.published
      expect(links).to match_array(published.map { |row| "/resources/#{row.resource_type}/#{row.to_param}" })
      expect(published.count).to be < record.downloadable_resources.count
    end

    it "reduces a tag's editor HTML to prose: no script, no runnable example, no script links" do
      DownloadableResourceTag.create!(
        name: 'Spec tag', slug: 'spec-tag',
        description: '<p onclick="x()">Text <a href="javascript:alert(1)">bad</a> <a href="/docs">good</a></p>' \
                     '<script>alert(1)</script><div class="tw-docs-playground"><textarea>alert(2)</textarea></div>'
      )
      get '/docs/spec-tag', headers: html_page

      segments = inertia.props[:doc][:segments]
      expect(segments.pluck(:kind)).to eq(['html'])
      html = segments.first[:html]
      expect(html).to include('<a href="/docs">good</a>')
      expect(html).not_to match(/onclick|javascript:|<script|<textarea|<div/)
    end

    it 'puts the old title and description in the head, with the canonical link' do
      get "/docs/#{tutorial}", headers: html_page

      head = Nokogiri::HTML(response.body)
      page = DocsPageService.new.find(tutorial)
      expect(head.at('title').text).to eq("#{page.title} — Download Resources — QUL Documentation")
      expect(head.at('meta[name="description"]')['content']).to eq(page.description)
      expect(head.at('link[rel="canonical"]')['href']).to eq("https://qul.tarteel.ai/docs/#{tutorial}")
    end

    it 'answers an Inertia visit with the new page' do
      get "/docs/#{guide}", headers: { 'X-Inertia' => 'true', 'X-Inertia-Version' => InertiaRails.configuration.version,
                                       'X-Requested-With' => 'XMLHttpRequest' }

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to include('component' => 'content/DocsPage')
    end

    it 'is a 404 in the new layout for an unknown key' do
      get '/docs/no-such-page', headers: html_page

      expect(response).to have_http_status(:not_found)
      expect(inertia).to render_component('errors/ErrorPage')
    end

    it 'keeps the old layout-free fragment for an XHR request' do
      get "/docs/#{tag}", xhr: true

      expect(controller).to be_a(CommunityController)
      expect(response.body).not_to include('<html')
      expect(Nokogiri::HTML(response.body).at('#body')).to be_present
    end

    it "keeps the old page for the help dialogs' fetch, which accepts anything" do
      get "/docs/#{tag}", headers: { 'Accept' => '*/*' }

      expect(controller).to be_a(CommunityController)
      html = Nokogiri::HTML(response.body)
      expect(html.at('#title').text.squish).to eq(DownloadableResourceTag.find_by!(slug: tag).name)
      expect(html.at('#body')).to be_present
    end

    it 'keeps the old page for a key only an ERB partial serves' do
      get '/docs/timestamp', headers: html_page

      expect(controller).to be_a(CommunityController)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Audio Timestamping tools')
    end
  end

  describe 'with the content page group off', page_groups: %w[home catalog apps] do
    it 'renders the old pages, unchanged' do
      [tutorial, guide, tag].each do |key|
        get "/docs/#{key}", headers: html_page

        expect(response).to have_http_status(:ok)
        expect(controller).to be_a(CommunityController)
        expect(Nokogiri::HTML(response.body).at('article.tw-docs')).to be_present
        expect(response.body).not_to include('data-page="app"')
      end
    end

    it 'keeps the old layout-free fragment for an XHR request' do
      get "/docs/#{tag}", xhr: true

      expect(controller).to be_a(CommunityController)
      expect(response.body).not_to include('<html')
    end
  end
end
