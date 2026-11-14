# frozen_string_literal: true

require 'clone_helper'

RSpec.describe 'Docs search index (/docs/search-index)', type: :request do
  let(:tutorial) { 'tutorial-recitation-end-to-end' }
  let(:html_page) { { 'Accept' => 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8' } }
  # What a body's HTML holds and its text does not: element tags with their attributes, entities.
  let(:markup) { /<(p|li|ul|ol|h[1-6]|code|pre|strong|em)>|<a href=|&(amp|lt|gt|quot|#\d+);/ }

  describe 'with the content page group on', page_groups: ['content'] do
    it 'has one entry per page of config/docs.yml, in reading order, with no markup' do
      get '/docs/search-index', headers: { 'Accept' => 'application/json' }

      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq('application/json')
      expect(response.headers['X-Robots-Tag']).to eq('noindex')
      pages = response.parsed_body['pages']
      expect(pages.pluck('key')).to eq(DocsManifest.pages_in_order.map(&:slug))
      pages.each do |page|
        expect(page.keys).to contain_exactly('key', 'title', 'category', 'headings', 'text'), page['key']
        expect(page['title']).to be_present, page['key']
        expect(page['text']).to be_present, page['key']
        strings = [page['title'], page['text'], *page['headings'].pluck('text')]
        # Prose may quote markup as inline code (`<b>, <i>`), never hold the body's own tags.
        expect(strings.join).not_to match(markup), page['key']
      end
    end

    it "matches a page's title, contents list and prose" do
      get '/docs/search-index'

      page = response.parsed_body['pages'].find { |entry| entry['key'] == tutorial }
      doc = Content::DocPage.find(tutorial)
      expect(page).to include('title' => doc.title, 'category' => 'Download Resources')
      expect(page['headings']).to eq(doc.contents.map { |heading| heading.to_h.stringify_keys })
      expect(page['headings'].first).to eq('id' => '1-what-this-resource-is', 'text' => '1) What This Resource Is',
                                           'level' => 2,)
      expect(page['text']).to include('Recitation resources provide Quran audio and related timing metadata.')
      expect(page['text']).to include('Segment timing arrays used for synchronized word or ayah highlighting')
      # The title and headings are their own fields, and code is not prose.
      expect(page['text']).not_to include('What This Resource Is', 'const words = [')
    end

    it 'leaves the docs pages to the new docs controller' do
      get '/docs/search-index', headers: html_page

      expect(controller).to be_a(Content::DocsSearchController)
    end
  end

  describe 'with the content page group off', page_groups: [] do
    it 'has no index' do
      get '/docs/search-index', headers: { 'Accept' => 'application/json' }

      expect(controller).not_to be_a(Content::DocsSearchController)
    end
  end

  describe 'the switch in the shared navigation prop' do
    it 'is on while the content page group is on', page_groups: ['content'] do
      get '/docs', headers: html_page

      expect(inertia.props.to_h.deep_symbolize_keys[:nav][:docsSearch]).to be(true)
    end

    it 'is off while the content page group is off', page_groups: ['catalog'] do
      get '/resources', headers: html_page

      expect(inertia.props.to_h.deep_symbolize_keys[:nav][:docsSearch]).to be(false)
    end
  end
end
