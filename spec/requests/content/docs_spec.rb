# frozen_string_literal: true

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

  describe 'with the content page group on', page_groups: ['content', 'catalog'] do
    it 'server-renders every page of config/docs.yml with the old headings, in order' do
      keys = DocsManifest.pages_in_order.map(&:slug)
      expect(keys).to include('api', 'project-setup', tutorial)

      SsrServer.with_ssr do
        keys.each do |key|
          expected = old_headings(key)
          get "/docs/#{key}", headers: html_page

          expect(response).to have_http_status(:ok), key
          expect(inertia).to render_component('content/DocsPage')
          expect(expected).not_to be_empty, key
          expect(headings(response.body, '#app[data-server-rendered="true"] article')).to eq(expected), key
        end
      end
    end

    it 'puts a title, description and canonical link in the head of every docs page, without SSR' do
      DocsManifest.pages_in_order.map(&:slug).each do |key|
        get "/docs/#{key}", headers: html_page

        head = Nokogiri::HTML(response.body)
        category = DocsManifest.category_for_page(key)
        expect(head.at('title').text).to match(/\A(.+ — )?#{Regexp.escape(category.title)} — QUL Documentation\z/), key
        expect(head.at('meta[name="description"]')['content']).to be_present, key
        expect(head.at('link[rel="canonical"]')['href']).to eq("https://qul.tarteel.ai/docs/#{key}")
        expect(response.body).not_to include('data-server-rendered')
      end
    end

    it 'renders every tag page the old site serves in the new layout' do
      slugs = DownloadableResourceTag.pluck(:slug).compact_blank.uniq
      slugs -= DocsManifest.pages_in_order.map(&:slug)
      slugs.reject! { |slug| Content::DocsRequest.partial_only?(slug) }
      expect(slugs).not_to be_empty

      slugs.each do |slug|
        get "/docs/#{slug}", headers: html_page

        expect(response).to have_http_status(:ok), slug
        expect(inertia).to render_component('content/DocsPage')
        expect(inertia.props[:doc][:kind]).to eq('tag'), slug
      end
    end

    it 'sends the docs navigation: the categories of config/docs.yml with their pages in reading order' do
      get "/docs/#{tutorial}", headers: html_page

      navigation = inertia.props[:navigation]
      expect(navigation.pluck(:key)).to eq(DocsManifest.categories.map(&:slug))
      expect(navigation.flat_map { |category| category[:pages].pluck(:key) })
        .to eq(DocsManifest.pages_in_order.map(&:slug))
      tutorials = navigation.first[:pages]
      expect(tutorials.find { |page| page[:key] == tutorial }).to include(title: 'Recitation', depth: 1)
      expect(tutorials.find { |page| page[:key] == 'tutorials' }).to include(depth: 0)
      expect(navigation.find { |category| category[:key] == 'api' }).to include(badge: 'Coming soon')
    end

    it 'serves the docs index from the manifest, with the old title and description' do
      get '/docs', headers: html_page

      expect(response).to have_http_status(:ok)
      expect(controller).to be_a(Content::DocsController)
      expect(inertia).to render_component('content/DocsIndexPage')
      expect(inertia.props[:navigation].pluck(:title)).to eq(DocsManifest.categories.map(&:title))
      head = Nokogiri::HTML(response.body)
      expect(head.at('title').text).to eq('QUL Documentation — Guides, Datasets & API Reference')
      expect(head.at('meta[name="description"]')['content']).to eq(CommunityPresenter::DOCS_INDEX_DESCRIPTION)
      expect(head.at('link[rel="canonical"]')['href']).to eq('https://qul.tarteel.ai/docs')
    end

    it 'server-renders the docs index and the side navigation of a page' do
      SsrServer.with_ssr do
        get '/docs', headers: html_page
        index = Nokogiri::HTML(response.body).at('#app[data-server-rendered="true"]')
        expect(index.css('h2 a').map { |link| link.text.squish }).to eq(DocsManifest.categories.map(&:title))

        get "/docs/#{tutorial}", headers: html_page
        current = Nokogiri::HTML(response.body).css('#app nav[aria-label="Docs"] a[aria-current="page"]')
        expect(current.map { |link| link['href'] }.uniq).to eq(["/docs/#{tutorial}"])
      end
    end

    it 'keeps the old layout-free docs index for an XHR request' do
      get '/docs', xhr: true

      expect(controller).to be_a(CommunityController)
      expect(response.body).not_to include('<html')
    end

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
        next: { key: 'tutorial-mushaf-layout-end-to-end', title: 'Mushaf Layout' },
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
                     '<script>alert(1)</script><div class="tw-docs-playground"><textarea>alert(2)</textarea></div>',
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
                                       'X-Requested-With' => 'XMLHttpRequest', }

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

  describe 'with the content page group off', page_groups: ['home', 'catalog', 'apps'] do
    it 'renders the old docs index, and its layout-free fragment for an XHR request' do
      get '/docs', headers: html_page
      expect(controller).to be_a(CommunityController)
      expect(response.body).to include('QUL Documentation')
      expect(response.body).not_to include('data-page="app"')

      get '/docs', xhr: true
      expect(controller).to be_a(CommunityController)
      expect(response.body).not_to include('<html')
    end

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
