# frozen_string_literal: true

require 'clone_helper'
require_relative '../../support/download_files'

# Resource requests in the CMS (/cms/resource_requests, app/admin/resource_requests.rb): editors set
# the status and hide requests. Only admins reach it, because a request names its author.
RSpec.describe 'Resource requests in the CMS (/cms/resource_requests)', type: :request do
  include DownloadFiles
  include Devise::Test::IntegrationHelpers

  let(:author) { create_account }
  let!(:resource_request) do
    ResourceRequest.create!(title: 'Spec Tafsir', description: 'For a study app.', resource_type: 'tafsir',
                            language: 'Bengali', user: author,).tap do |request|
      ResourceRequestVote.create!(resource_request: request, user: create_account)
    end
  end

  describe 'as an admin' do
    before { sign_in create_account(role: :admin) }

    it 'lists requests and shows one with its author' do
      get '/cms/resource_requests'
      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Spec Tafsir')

      get "/cms/resource_requests/#{resource_request.id}"
      expect(response).to have_http_status(:ok)
      expect(response.body).to include(author.email)
    end

    it 'sets the status and hides a request' do
      get "/cms/resource_requests/#{resource_request.id}/edit"
      expect(response).to have_http_status(:ok)

      patch "/cms/resource_requests/#{resource_request.id}",
            params: { resource_request: { status: 'planned', hidden: '1', title: 'Changed' } }

      expect(response).to redirect_to("/cms/resource_requests/#{resource_request.id}")
      expect(resource_request.reload).to have_attributes(status: 'planned', hidden: true, title: 'Spec Tafsir')
    end

    it 'refuses a status that is not in the list' do
      patch "/cms/resource_requests/#{resource_request.id}", params: { resource_request: { status: 'shipped' } }

      expect(response).to have_http_status(:ok)
      expect(resource_request.reload.status).to eq('open')
    end
  end

  describe 'as a signed-in user who is not an admin' do
    before { sign_in create_account }

    it 'cannot reach the list or a request, or change one' do
      get '/cms/resource_requests'
      expect(response).to have_http_status(:redirect)
      expect(response.location).not_to include('/cms/resource_requests')

      get "/cms/resource_requests/#{resource_request.id}"
      expect(response).to have_http_status(:redirect)

      patch "/cms/resource_requests/#{resource_request.id}",
            params: { resource_request: { status: 'planned', hidden: '1' } }
      expect(resource_request.reload).to have_attributes(status: 'open', hidden: false)
    end
  end

  describe 'as a moderator' do
    before { sign_in create_account(role: :moderator) }

    it 'cannot reach the list' do
      get '/cms/resource_requests'
      expect(response).to have_http_status(:redirect)
      expect(response.location).not_to include('/cms/resource_requests')
    end
  end

  it 'sends an anonymous visitor to sign-in' do
    get '/cms/resource_requests'
    expect(response).to redirect_to('/users/sign_in')
  end
end
