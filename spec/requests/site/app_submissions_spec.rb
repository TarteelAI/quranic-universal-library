# frozen_string_literal: true

require 'clone_helper'
require_relative '../../support/download_files'

# The app submission form on /apps posts to POST /apps (Site::AppSubmissionsController). Only a
# signed-in user can submit; a submission is an unpublished App row with an optional icon.
RSpec.describe 'App submissions (POST /apps)', type: :request do
  include DownloadFiles
  include ActiveJob::TestHelper
  include Devise::Test::IntegrationHelpers

  let(:inertia_headers) { { 'X-Inertia' => 'true' } }
  let(:icon) { Rack::Test::UploadedFile.new(Rails.public_path.join('app-icons/bayaan.png'), 'image/png') }
  let(:valid_app) do
    { name: 'Spec Reader', url: 'https://example.test/spec-reader', platforms: ['ios', 'web'],
      description: 'Reads the Quran with translations.', uses: ['translation', 'recitation'],
      contact: 'maker@example.test', consent: '1', }
  end

  def submit(app, headers: inertia_headers)
    post '/apps', params: { app: app }, headers: headers
  end

  describe 'with the apps page group on', page_groups: ['apps'] do
    it 'refuses an anonymous Inertia submit with a full visit to sign-in that returns to the open form' do
      expect { submit(valid_app.merge(icon: icon)) }.not_to change(App, :count)

      expect(response).to have_http_status(:conflict)
      expect(response.headers['X-Inertia-Location']).to eq('/users/sign_in?user_return_to=%2Fapps%3Fsubmit%3D1')
    end

    it 'refuses an anonymous plain form post with a redirect to sign-in' do
      expect { submit(valid_app, headers: {}) }.not_to change(App, :count)

      expect(response).to redirect_to('/users/sign_in?user_return_to=%2Fapps%3Fsubmit%3D1')
    end

    it 'creates one unpublished app with the icon attached for a signed-in user' do
      user = create_account
      sign_in user

      links = { app_store_url: 'https://apps.apple.com/app/id1', source_url: 'https://github.com/example/spec-reader' }
      expect { submit(valid_app.merge(icon: icon, published: '1', position: '1', **links)) }
        .to change(App, :count).by(1)

      expect(response).to redirect_to('/apps')
      app = App.last
      expect(app).to have_attributes(name: 'Spec Reader', url: 'https://example.test/spec-reader', **links,
                                     project_type: 'app', description: 'Reads the Quran with translations.',
                                     play_store_url: nil, platforms: ['ios', 'web'],
                                     uses: ['translation', 'recitation'], contact: 'maker@example.test', consent: true,
                                     published: false, position: nil, user: user,)
      expect(app.icon).to be_attached
      expect(app.icon.blob).to have_attributes(content_type: 'image/png',
                                               filename: ActiveStorage::Filename.new('icon.png'),
                                               byte_size: File.size(Rails.public_path.join('app-icons/bayaan.png')),)
      expect(app.icon.blob.service_name).to eq('test')
    end

    it 'creates the app without an icon, from the JSON body Inertia sends when there is no file' do
      sign_in create_account

      expect do
        post '/apps', params: { app: valid_app.merge(consent: true) }.to_json,
                      headers: inertia_headers.merge('Content-Type' => 'application/json')
      end.to change(App, :count).by(1)

      expect(App.last.icon).not_to be_attached
    end

    it 'refuses a signed-in submit without the XSRF token' do
      sign_in create_account
      original = ActionController::Base.allow_forgery_protection
      ActionController::Base.allow_forgery_protection = true

      expect { submit(valid_app) }.not_to change(App, :count)
      expect(response).to have_http_status(:unprocessable_content)
    ensure
      ActionController::Base.allow_forgery_protection = original
    end

    it 'enqueues no job and sends no mail' do
      sign_in create_account
      deliveries = ActionMailer::Base.deliveries.size

      expect { submit(valid_app.merge(icon: icon)) }.not_to have_enqueued_job

      expect(App.last.icon).to be_attached
      expect(ActionMailer::Base.deliveries.size).to eq(deliveries)
    end

    it 'creates no row for invalid input and returns the errors as Inertia props on the page it goes back to' do
      sign_in create_account
      not_an_image = Rack::Test::UploadedFile.new(StringIO.new('<html>not an image</html>'), 'image/png',
                                                  original_filename: 'icon.png',)
      invalid = { name: '', url: 'javascript:alert(1)', source_url: 'ftp://example.test',
                  platforms: ['palm-os'], uses: ['hadith'], contact: 'not an address', consent: '0',
                  icon: not_an_image, }

      expect { submit(invalid, headers: inertia_headers.merge('Referer' => 'http://localhost/apps?platform=web')) }
        .not_to change(App, :count)

      expect(response).to redirect_to('/apps?platform=web')
      follow_redirect!(headers: inertia_headers)
      expect(inertia).to render_component('site/AppsPage')
      expect(inertia.props[:errors]).to eq(
        'name' => ["Name can't be blank"],
        'url' => ['Link must be a web address starting with http:// or https://'],
        'source_url' => ['Source code link must be a web address starting with http:// or https://'],
        'description' => ["Description can't be blank"],
        'platforms' => ['Platforms must be chosen from the list'],
        'uses' => ['Resources used must be chosen from the list'],
        'contact' => ['Contact email must be an email address'],
        'consent' => ['Consent must be given to list the app'],
        'icon' => ['Icon must be a PNG, JPEG or WebP image'],
      )
    end

    it 'answers a text value in place of the icon file with an icon error' do
      sign_in create_account

      expect { submit(valid_app.merge(icon: 'not a file')) }.not_to change(App, :count)

      follow_redirect!(headers: inertia_headers)
      expect(inertia.props[:errors]).to eq('icon' => ['Icon must be a PNG, JPEG or WebP image'])
    end

    it 'asks for at least one platform and one resource type, and caps the icon size' do
      sign_in create_account
      big = Rack::Test::UploadedFile.new(
        StringIO.new("\x89PNG\r\n\x1A\n".b + ("\0" * App::ICON_MAX_SIZE).b), 'image/png', true,
        original_filename: 'big.png',
      )

      expect { submit(valid_app.merge(platforms: [], uses: [], icon: big)) }.not_to change(App, :count)

      follow_redirect!(headers: inertia_headers)
      expect(inertia.props[:errors]).to include('platforms' => ['Platforms must include at least one platform'],
                                                'uses' => ['Resources used must include at least one resource type'],
                                                'icon' => ['Icon must be 1 MB or smaller'],)
    end

    it 'takes a library without platforms, and drops any platforms or store links sent with it' do
      sign_in create_account

      library = valid_app.merge(project_type: 'library', app_store_url: 'https://apps.apple.com/app/id1',
                                play_store_url: 'https://play.google.com/store/apps/details?id=a.b',)
      expect { submit(library) }.to change(App, :count).by(1)
      expect(App.last).to have_attributes(project_type: 'library', platforms: [], app_store_url: nil,
                                          play_store_url: nil,)

      expect { submit(valid_app.merge(project_type: 'tool', platforms: [])) }.to change(App, :count).by(1)

      expect { submit(valid_app.merge(project_type: 'game')) }.not_to change(App, :count)
      follow_redirect!(headers: inertia_headers)
      expect(inertia.props[:errors]).to eq('project_type' => ['Type must be chosen from the list'])
    end

    describe 'the daily limit' do
      include ActiveSupport::Testing::TimeHelpers

      let(:user) { create_account }
      let(:limit_error) { { 'base' => ['You can send at most 3 apps a day. Try again tomorrow.'] } }

      before { sign_in user }

      it 'refuses a fourth submission on the same day with a message, and takes the first one of the next day' do
        travel_to Time.zone.parse('2026-11-13 00:05') do
          3.times { |n| submit(valid_app.merge(name: "Spec Reader #{n}")) }
        end
        expect(App.where(user: user).count).to eq(3)

        travel_to Time.zone.parse('2026-11-13 23:55') do
          expect { submit(valid_app.merge(name: 'Spec Reader 4')) }.not_to change(App, :count)

          follow_redirect!(headers: inertia_headers)
          expect(inertia.props[:errors]).to eq(limit_error)
        end

        travel_to Time.zone.parse('2026-11-14 00:05') do
          expect { submit(valid_app.merge(name: 'Spec Reader 4')) }.to change(App, :count).by(1)
          expect(response).to redirect_to('/apps')
        end
      end

      it "counts only the user's own rows" do
        other = create_account
        3.times { |n| App.create!(valid_app.except(:consent).merge(name: "Other #{n}", user: other)) }

        expect { submit(valid_app) }.to change(App, :count).by(1)
      end
    end
  end

  describe 'with the apps page group off', page_groups: ['home', 'catalog'] do
    it 'has no submission route' do
      sign_in create_account

      expect { submit(valid_app) }.not_to change(App, :count)
      expect(response).to have_http_status(:not_found)
    end
  end
end
