# frozen_string_literal: true

require 'clone_helper'
require_relative '../../support/download_files'

# The write paths of resource requests (`requests` page group, Requests::RequestsController):
# POST /requests creates a request, POST /requests/:id/vote votes and DELETE /requests/:id/vote
# takes the vote back. Each needs a signed-in user and enqueues nothing.
RSpec.describe 'Request writes (POST /requests, POST and DELETE /requests/:id/vote)', type: :request do
  include DownloadFiles
  include ActiveJob::TestHelper
  include Devise::Test::IntegrationHelpers

  let(:inertia_headers) { { 'X-Inertia' => 'true', 'Referer' => 'http://localhost/resources/translation' } }
  let(:valid_request) do
    { title: 'Tafsir Ahsanul Bayan', description: 'For a Bengali study app.', resource_type: 'tafsir',
      language: 'Bengali', }
  end
  let(:author) { create_account }
  let!(:resource_request) { ResourceRequest.create!(valid_request.merge(user: author)) }

  def submit(fields, headers: inertia_headers)
    post '/requests', params: { request: fields }, headers: headers
  end

  def vote(target = resource_request, headers: inertia_headers)
    post "/requests/#{target.id}/vote", headers: headers
  end

  def unvote(target = resource_request, headers: inertia_headers)
    delete "/requests/#{target.id}/vote", headers: headers
  end

  def row_counts
    [ResourceRequest.count, ResourceRequestVote.count]
  end

  describe 'with the requests page group on', page_groups: ['catalog', 'requests'] do
    describe 'an anonymous visitor' do
      let!(:existing_vote) { ResourceRequestVote.create!(resource_request: resource_request, user: create_account) }

      it 'cannot create a request: an Inertia post gets a full visit to sign-in that returns to the page' do
        expect { submit(valid_request) }.not_to change(self, :row_counts)

        expect(response).to have_http_status(:conflict)
        expect(response.headers['X-Inertia-Location'])
          .to eq('/users/sign_in?user_return_to=%2Fresources%2Ftranslation')
      end

      it 'cannot create a request with a plain form post' do
        expect { submit(valid_request, headers: {}) }.not_to change(self, :row_counts)

        expect(response).to redirect_to('/users/sign_in')
      end

      it 'cannot vote' do
        expect { vote }.not_to change(self, :row_counts)

        expect(response).to have_http_status(:conflict)
      end

      it 'cannot take a vote back' do
        expect { unvote }.not_to change(self, :row_counts)

        expect(response).to have_http_status(:conflict)
        expect(existing_vote.reload).to be_persisted
      end

      it 'is not sent back to another site after sign-in' do
        submit(valid_request, headers: inertia_headers.merge('Referer' => 'https://example.test/elsewhere'))

        expect(response.headers['X-Inertia-Location']).to eq('/users/sign_in')
      end
    end

    describe 'a signed-in user creating a request' do
      let(:user) { create_account }

      before { sign_in user }

      it 'makes one open, visible row with the user as author and goes back to the page' do
        expect { submit(valid_request.merge(status: 'added', hidden: '1')) }.to change(ResourceRequest, :count).by(1)

        expect(response).to redirect_to('/resources/translation')
        expect(ResourceRequest.last).to have_attributes(
          title: 'Tafsir Ahsanul Bayan', description: 'For a Bengali study app.', resource_type: 'tafsir',
          language: 'Bengali', status: 'open', hidden: false, user: user,
        )
      end

      it 'takes the JSON body Inertia sends and stores no language when none is given' do
        expect do
          post '/requests', params: { request: valid_request.merge(language: ' ') }.to_json,
                            headers: inertia_headers.merge('Content-Type' => 'application/json')
        end.to change(ResourceRequest, :count).by(1)

        expect(ResourceRequest.last.language).to be_nil
      end

      it 'makes no row for invalid input and returns the errors as Inertia props' do
        invalid = { title: ' ', description: '', resource_type: 'hadith', language: 'x' * 61 }

        expect { submit(invalid) }.not_to change(ResourceRequest, :count)

        expect(response).to redirect_to('/resources/translation')
        follow_redirect!(headers: inertia_headers)
        expect(inertia.props[:errors]).to eq(
          'title' => ["Title can't be blank"],
          'description' => ["Description can't be blank"],
          'resource_type' => ['Resource type must be chosen from the list'],
          'language' => ['Language is too long (maximum is 60 characters)'],
        )
      end

      it 'refuses a request without the XSRF token' do
        original = ActionController::Base.allow_forgery_protection
        ActionController::Base.allow_forgery_protection = true

        expect { submit(valid_request) }.not_to change(ResourceRequest, :count)
        expect(response).to have_http_status(:unprocessable_content)
      ensure
        ActionController::Base.allow_forgery_protection = original
      end

      describe 'the daily limit' do
        include ActiveSupport::Testing::TimeHelpers

        let(:limit_error) { { 'base' => ['You can send at most 5 requests a day. Try again tomorrow.'] } }

        it 'refuses a sixth request on the same day with a message, and takes the first one of the next day' do
          travel_to Time.zone.parse('2026-11-13 00:05') do
            5.times { |n| submit(valid_request.merge(title: "Request #{n}")) }
          end
          expect(ResourceRequest.where(user: user).count).to eq(5)

          travel_to Time.zone.parse('2026-11-13 23:55') do
            expect { submit(valid_request.merge(title: 'Request 6')) }.not_to change(ResourceRequest, :count)

            follow_redirect!(headers: inertia_headers)
            expect(inertia.props[:errors]).to eq(limit_error)
          end

          travel_to Time.zone.parse('2026-11-14 00:05') do
            expect { submit(valid_request.merge(title: 'Request 6')) }.to change(ResourceRequest, :count).by(1)
          end
        end

        it "counts only the user's own rows" do
          5.times { |n| ResourceRequest.create!(valid_request.merge(title: "Other #{n}", user: author)) }

          expect { submit(valid_request) }.to change(ResourceRequest, :count).by(1)
        end
      end
    end

    describe 'a signed-in user voting' do
      let(:user) { create_account }

      before { sign_in user }

      it 'adds one vote and goes back to the page' do
        expect { vote }.to change(ResourceRequestVote, :count).by(1)

        expect(response).to redirect_to('/resources/translation')
        expect(resource_request.votes.sole.user).to eq(user)
      end

      it 'changes nothing on a second vote' do
        vote

        expect { vote }.not_to change(self, :row_counts)
        expect(response).to redirect_to('/resources/translation')
      end

      it 'changes nothing when a vote of the same user was stored in the meantime, as when two votes race' do
        ResourceRequestVote.create!(resource_request: resource_request, user: user)

        expect { vote }.not_to change(self, :row_counts)
        expect(response).to redirect_to('/resources/translation')
      end

      it 'is held by the unique index (resource_request_id, user_id), not by a check before the insert' do
        ResourceRequestVote.create!(resource_request: resource_request, user: user)

        expect { ResourceRequestVote.create!(resource_request: resource_request, user: user) }
          .to raise_error(ActiveRecord::RecordNotUnique, /index_resource_request_votes_unique/)
      end

      it "takes back exactly the user's own vote" do
        other_vote = ResourceRequestVote.create!(resource_request: resource_request, user: create_account)
        other_request = ResourceRequest.create!(valid_request.merge(title: 'Other request', user: author))
        vote
        vote(other_request)

        expect { unvote }.to change(ResourceRequestVote, :count).by(-1)

        expect(response).to redirect_to('/resources/translation')
        expect(resource_request.votes.reload).to eq([other_vote])
        expect(other_request.votes.sole.user).to eq(user)
      end

      it 'changes nothing when taking back a vote the user does not have' do
        ResourceRequestVote.create!(resource_request: resource_request, user: create_account)

        expect { unvote }.not_to change(self, :row_counts)
      end

      it 'cannot vote on a hidden request or one that does not exist' do
        resource_request.update!(hidden: true)

        expect { vote }.not_to change(self, :row_counts)
        expect(response).to have_http_status(:not_found)

        post "/requests/#{ResourceRequest.maximum(:id) + 1}/vote", headers: inertia_headers
        expect(response).to have_http_status(:not_found)
      end
    end

    it 'enqueues no job and sends no mail on any write' do
      sign_in create_account
      deliveries = ActionMailer::Base.deliveries.size

      expect do
        submit(valid_request)
        vote
        unvote
      end.not_to have_enqueued_job

      expect(response).to redirect_to('/resources/translation')
      expect(ActionMailer::Base.deliveries.size).to eq(deliveries)
    end
  end

  describe 'with the requests page group off', page_groups: ['home', 'catalog', 'apps', 'content', 'start'] do
    it 'has no write routes' do
      sign_in create_account

      expect { submit(valid_request) }.not_to change(self, :row_counts)
      expect(response).to have_http_status(:not_found)

      expect { vote }.not_to change(self, :row_counts)
      expect(response).to have_http_status(:not_found)

      unvote
      expect(response).to have_http_status(:not_found)
    end
  end
end
