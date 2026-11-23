# frozen_string_literal: true

require 'clone_helper'
require_relative '../../support/download_files'

# The apps directory in the CMS (/cms/apps, app/admin/apps.rb): editors publish, edit, feature and
# remove apps. Only admins reach it, because a submission holds the submitter's contact address.
RSpec.describe 'Apps in the CMS (/cms/apps)', type: :request do
  include DownloadFiles
  include Devise::Test::IntegrationHelpers

  let!(:submission) do
    App.create!(name: 'Spec Submission', url: 'https://example.test/spec-submission', platforms: ['ios'],
                uses: ['translation'], contact: 'maker@example.test', consent: true, user: create_account,)
  end

  describe 'as an admin' do
    before { sign_in create_account(role: :admin) }

    it 'lists submissions with their contact and shows one' do
      get '/cms/apps'
      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Spec Submission')

      get "/cms/apps/#{submission.id}"
      expect(response).to have_http_status(:ok)
      expect(response.body).to include('maker@example.test')
    end

    it 'edits, publishes and features an app' do
      get "/cms/apps/#{submission.id}/edit"
      expect(response).to have_http_status(:ok)

      patch "/cms/apps/#{submission.id}", params: {
        app: { name: 'Spec Reader', kind: 'Quran reader', description: 'Reads the Quran.', published: '1',
               featured: '1', platforms: ['', 'web', 'android'], uses: ['', 'quran-script'], },
      }

      expect(response).to redirect_to("/cms/apps/#{submission.id}")
      expect(submission.reload).to have_attributes(name: 'Spec Reader', kind: 'Quran reader',
                                                   description: 'Reads the Quran.', published: true,
                                                   featured: true, platforms: ['web', 'android'],
                                                   uses: ['quran-script'],)
    end

    it 'replaces the icon with an uploaded file' do
      icon = Rack::Test::UploadedFile.new(Rails.public_path.join('app-icons/bayaan.png'), 'image/png')

      patch "/cms/apps/#{submission.id}", params: { app: { icon_upload: icon } }

      expect(submission.reload.icon.blob).to have_attributes(content_type: 'image/png',
                                                             filename: ActiveStorage::Filename.new('icon.png'),)
    end

    it 'does not publish an app without the kind and description the directory shows' do
      patch "/cms/apps/#{submission.id}", params: { app: { published: '1' } }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('can&#39;t be blank')
      expect(submission.reload.published).to be(false)
    end

    it 'removes an app' do
      expect { delete "/cms/apps/#{submission.id}" }.to change(App, :count).by(-1)
      expect(response).to redirect_to('/cms/apps')
    end
  end

  describe 'as a signed-in user who is not an admin' do
    before { sign_in create_account }

    it 'cannot reach the list, an app, or change one' do
      get '/cms/apps'
      expect(response).to have_http_status(:redirect)
      expect(response.location).not_to include('/cms/apps')

      get "/cms/apps/#{submission.id}"
      expect(response).to have_http_status(:redirect)

      patch "/cms/apps/#{submission.id}", params: { app: { published: '1', kind: 'x', description: 'x' } }
      delete "/cms/apps/#{submission.id}"
      expect(submission.reload).to have_attributes(published: false, kind: nil)
    end
  end

  describe 'as a moderator' do
    before { sign_in create_account(role: :moderator) }

    it 'cannot reach the list' do
      get '/cms/apps'
      expect(response).to have_http_status(:redirect)
      expect(response.location).not_to include('/cms/apps')
    end
  end

  it 'sends an anonymous visitor to sign-in' do
    get '/cms/apps'
    expect(response).to redirect_to('/users/sign_in')
  end
end
