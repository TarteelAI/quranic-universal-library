# frozen_string_literal: true

require 'clone_helper'
require_relative '../../support/download_files'

# The public requests page (`requests` page group, Requests::RequestsController#index): visible
# requests with status and votes, by votes or by date, Requests::ListQuery::PER_PAGE to a page.
RSpec.describe 'The requests page (/requests)', type: :request do
  include DownloadFiles
  include Devise::Test::IntegrationHelpers

  let(:author) { create_account }

  def create_request(title, votes: 0, created_at: Time.current, **fields)
    ResourceRequest.create!(title:, description: "#{title} for a study app.", resource_type: 'tafsir',
                            user: author, created_at:, **fields,).tap do |request|
      votes.times { ResourceRequestVote.create!(resource_request: request, user: create_account) }
    end
  end

  def head
    Nokogiri::HTML(response.body).at('head')
  end

  describe 'with the requests page group on', page_groups: ['catalog', 'requests'] do
    it 'lists the visible requests by votes, server-rendered, with a title, description and canonical link' do
      popular = create_request('Hausa translation', votes: 2, resource_type: 'translation', language: 'Hausa',
                                                    status: 'planned',)
      create_request('Tafsir Ahsanul Bayan', votes: 1)
      create_request('Hidden spam', votes: 3, hidden: true)

      SsrServer.with_ssr { get '/requests' }

      expect(response).to have_http_status(:ok)
      expect(inertia).to render_component('requests/RequestsPage')
      expect(inertia.props).to include(sort: 'votes', page: 1, pages: 1, total: 2)
      expect(inertia.props[:requests].pluck(:title)).to eq(['Hausa translation', 'Tafsir Ahsanul Bayan'])
      expect(inertia.props[:requests].first.deep_symbolize_keys).to eq(
        id: popular.id, title: 'Hausa translation', description: 'Hausa translation for a study app.',
        type: 'Translation', language: 'Hausa', status: 'planned', statusLabel: 'Planned', votes: 2, voted: false,
        date: popular.created_at.strftime('%-d %B %Y'),
      )
      expect(response.body).not_to include('Hidden spam', author.email)

      app = Nokogiri::HTML(response.body).at('#app[data-server-rendered="true"]')
      expect(app.css('ol[aria-label="Requests"] > li h2').map(&:text)).to eq(['Hausa translation',
                                                                              'Tafsir Ahsanul Bayan',])
      expect(head.at('title').text).to eq('Resource requests - QUL')
      expect(head.at('meta[name="description"]')['content']).to be_present
      expect(head.at('link[rel="canonical"]')['href']).to eq('https://qul.tarteel.ai/requests')
    end

    it 'sorts by date from the URL, and falls back to votes for an unknown sort' do
      older = create_request('Older with votes', votes: 2, created_at: 2.days.ago)
      newer = create_request('Newer without votes', created_at: 1.day.ago)

      get '/requests', params: { sort: 'date' }
      expect(inertia.props[:sort]).to eq('date')
      expect(inertia.props[:requests].pluck(:id).first(2)).to eq([newer.id, older.id])

      get '/requests', params: { sort: 'nonsense' }
      expect(inertia.props[:sort]).to eq('votes')
      expect(inertia.props[:requests].first[:id]).to eq(older.id)
    end

    it 'pages through the list without repeating a request, and answers 404 past the last page' do
      per_page = Requests::ListQuery::PER_PAGE
      (per_page + 3).times { |i| create_request("Request #{i}", created_at: i.minutes.ago) }

      get '/requests', params: { sort: 'date' }
      first = inertia.props[:requests].pluck(:id)
      expect(inertia.props).to include(page: 1, pages: 2, total: per_page + 3)

      get '/requests', params: { sort: 'date', page: 2 }
      second = inertia.props[:requests].pluck(:id)
      expect([first.size, second.size]).to eq([per_page, 3])
      expect(first & second).to be_empty

      ['3', '0', 'two', '1.5', '99999999999999999999'].each do |page|
        get '/requests', params: { page: }

        expect(response).to have_http_status(:not_found), page
        expect(inertia).to render_component('errors/ErrorPage'), page
      end
      get '/requests?page[]=1'
      expect(response).to have_http_status(:not_found)
    end

    it 'shows an empty first page when there is no request' do
      get '/requests'

      expect(response).to have_http_status(:ok)
      expect(inertia.props).to include(requests: [], page: 1, pages: 1, total: 0)
    end

    it 'marks the requests the signed-in user voted for' do
      user = create_account
      mine = create_request('Voted', votes: 1)
      ResourceRequestVote.create!(resource_request: mine, user:)
      create_request('Not voted', votes: 1)
      sign_in user

      get '/requests'

      expect(inertia.props[:requests].pluck(:title, :votes, :voted)).to eq([['Voted', 2, true],
                                                                            ['Not voted', 1, false],])
    end

    it 'sends back only the list after a vote, so the page updates it in place' do
      request = create_request('Voted in place')
      sign_in create_account
      headers = { 'X-Inertia' => 'true', 'X-Inertia-Version' => InertiaRails.configuration.version.to_s,
                  'X-Inertia-Partial-Component' => 'requests/RequestsPage', 'X-Inertia-Partial-Data' => 'requests',
                  'Referer' => 'http://localhost/requests', }

      post "/requests/#{request.id}/vote", headers: headers
      expect(response).to redirect_to('http://localhost/requests')
      get '/requests', headers: headers

      expect(response.parsed_body['props'].keys).to contain_exactly('requests', 'errors', 'head')
      expect(response.parsed_body['props']['requests'].first).to include('votes' => 1, 'voted' => true)
    end
  end

  describe 'with the requests page group off', page_groups: ['catalog'] do
    it 'is a 404' do
      get '/requests'

      expect(response).to have_http_status(:not_found)
    end
  end
end
