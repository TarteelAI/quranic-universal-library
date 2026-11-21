# frozen_string_literal: true

require 'clone_helper'
require_relative '../../support/download_files'

# The signed-in user's own pages (`account` page group, Account::ProfilesController): the profile
# (/profile), the account settings (/profile/edit) and the update (PATCH /profile).
RSpec.describe 'The profile and account settings (/profile, /profile/edit)', type: :request do
  include DownloadFiles
  include Devise::Test::IntegrationHelpers

  let(:user) { create_account }
  let(:inertia_headers) { { 'X-Inertia' => 'true', 'X-Inertia-Version' => InertiaRails.configuration.version.to_s } }

  def add_download(account, at: Time.current)
    resource = create_download_resource
    UserDownload.create!(user: account, downloadable_file: create_download_file(resource),
                         downloadable_resource: resource, download_count: 1, last_download_at: at,)
    resource
  end

  def add_contributions(account, count, item_type: 'Translation')
    Array.new(count) do |i|
      PaperTrail::Version.create!(item_type:, item_id: 2_000_000_000 - i, event: 'update', user_id: account.id,
                                  created_at: i.minutes.ago,)
    end
  end

  def update_account(fields)
    patch '/profile', params: { user: fields }, headers: inertia_headers
  end

  describe 'with the account page group on', page_groups: ['catalog', 'requests', 'account'] do
    describe 'an anonymous visitor' do
      it 'is sent to sign-in, which returns to the page' do
        get '/profile', params: { tab: 'requests' }
        expect(response).to redirect_to('/users/sign_in?user_return_to=%2Fprofile%3Ftab%3Drequests')

        get '/profile/edit'
        expect(response).to redirect_to('/users/sign_in?user_return_to=%2Fprofile%2Fedit')
      end

      it 'leaves the app with a full visit on an Inertia request, and changes nothing' do
        get '/profile', headers: inertia_headers
        expect(response).to have_http_status(:conflict)
        expect(response.headers['X-Inertia-Location']).to eq('/users/sign_in?user_return_to=%2Fprofile')

        update_account(first_name: 'Changed')
        expect(response).to have_http_status(:conflict)
        expect(response.headers['X-Inertia-Location']).to eq('/users/sign_in?user_return_to=%2Fprofile%2Fedit')
      end
    end

    describe 'the profile' do
      before { sign_in user }

      it 'shows the user, a count for each tab and the downloads, server-rendered and not indexed' do
        resource = add_download(user, at: 1.hour.from_now)
        stale = add_download(user, at: 2.days.ago)
        add_download(create_account)
        add_contributions(user, 2)

        SsrServer.with_ssr { get '/profile' }

        expect(response).to have_http_status(:ok)
        expect(inertia).to render_component('account/ProfilePage')
        expect(inertia.props).to include(tab: 'downloads', page: 1, pages: 1, catalog: true, contributions: nil,
                                         accesses: nil, requests: nil,)
        expect(inertia.props[:person].symbolize_keys).to eq(
          name: 'Spec Account', initials: 'SA', email: user.email, memberSince: user.created_at.strftime('%B %Y'),
          about: nil,
        )
        expect(inertia.props[:counts].symbolize_keys).to eq(downloads: 2, contributions: 2, resources: 0, requests: 0)
        expect(inertia.props[:downloads].map(&:symbolize_keys)).to match([
          a_hash_including(name: resource.name, type: 'Tafsir', updateAvailable: false,
                           path: "/resources/tafsir/#{resource.to_param}",),
          a_hash_including(name: stale.name, updateAvailable: true),
        ])

        page = Nokogiri::HTML(response.body)
        expect(page.at('#app[data-server-rendered="true"] h1').text).to eq('Spec Account')
        expect(page.at('head title').text).to eq('Your profile - QUL')
        expect(page.at('head meta[name="robots"]')['content']).to include('noindex')
      end

      it 'does not link a download whose resource is no longer published' do
        add_download(user).update!(published: false)

        get '/profile'

        expect(inertia.props[:downloads].first).to include(path: nil)
      end

      it 'shows the about text as prose, without the script an old editor value could hold' do
        user.update!(about_me: '<p>Builds <strong>apps</strong></p><script>alert(1)</script>')

        get '/profile'

        expect(inertia.props[:person][:about]).to include('<strong>apps</strong>')
        expect(inertia.props[:person][:about]).not_to include('script', 'alert')

        user.update!(about_me: "Plain text\nwith <no> tags")
        get '/profile'
        expect(inertia.props[:person][:about]).to eq("<p>Plain text\n<br>with &lt;no&gt; tags</p>")
      end

      it 'pages through the contributions and filters them by type, and answers 404 past the last page' do
        add_contributions(user, Account::Profile::CONTRIBUTIONS_PER_PAGE + 1)
        add_contributions(user, 1, item_type: 'Tafsir')
        add_contributions(create_account, 1)

        get '/profile', params: { tab: 'contributions', page: 2 }
        expect(inertia.props).to include(tab: 'contributions', page: 2, pages: 2, downloads: nil)
        expect(inertia.props[:contributions].size).to eq(2)
        expect(inertia.props[:filter].deep_symbolize_keys).to eq(
          param: 'item_type', value: nil,
          options: [{ key: 'Tafsir', label: 'Tafsirs' }, { key: 'Translation', label: 'Translations' }],
        )

        get '/profile', params: { tab: 'contributions', item_type: 'Tafsir' }
        expect(inertia.props).to include(pages: 1)
        expect(inertia.props[:contributions].pluck(:type)).to eq(['Tafsir'])

        ['3', '0', 'two'].each do |page|
          get '/profile', params: { tab: 'contributions', page: }
          expect(response).to have_http_status(:not_found), page
        end
      end

      it 'lists the resources the user asked to edit, with a tool link once approved' do
        approved, pending = ResourceContent.where(sub_type: 'tafsir').order(:id).limit(2).map.with_index do |content, i|
          UserProject.new(user:, resource_content: content, approved: i.zero?).tap { |row| row.save!(validate: false) }
        end

        get '/profile', params: { tab: 'resources' }

        expect(inertia.props[:accesses].map(&:symbolize_keys)).to match([
          a_hash_including(id: approved.id, tool: 'Tafsir', approved: true, path: a_string_starting_with('/tafsirs')),
          a_hash_including(id: pending.id, approved: false, path: nil),
        ])
      end

      it 'lists the visible requests the user sent, with their votes' do
        fields = { description: 'For a study app.', resource_type: 'tafsir' }
        mine = ResourceRequest.create!(title: 'Mine', user:, status: 'planned', **fields)
        ResourceRequestVote.create!(resource_request: mine, user: create_account)
        ResourceRequest.create!(title: 'Hidden', user:, hidden: true, **fields)
        ResourceRequest.create!(title: 'Not mine', user: create_account, **fields)

        get '/profile', params: { tab: 'requests' }

        expect(inertia.props[:counts]).to include(requests: 1)
        expect(inertia.props[:requests].map(&:symbolize_keys)).to match([
          a_hash_including(title: 'Mine', status: 'planned', statusLabel: 'Planned', votes: 1),
        ])
      end

      it 'has no requests tab while the requests group is off', page_groups: ['account'] do
        get '/profile', params: { tab: 'requests' }

        expect(inertia.props).to include(tab: 'downloads', catalog: false, requests: nil)
        expect(inertia.props[:counts]).to include(requests: nil)
      end
    end

    describe 'the account settings' do
      before { sign_in user }

      it 'shows the values the forms start from, with editor HTML as plain text' do
        user.update!(about_me: '<p>First line</p><p>Second <em>line</em></p>')

        get '/profile/edit'

        expect(inertia).to render_component('account/SettingsPage')
        expect(inertia.props).to include(
          firstName: 'Spec', lastName: 'Account', email: user.email, emailStatus: 'confirmed',
          unconfirmedEmail: nil, about: "First line\nSecond line",
        )
      end

      it 'keeps plain about text as the user wrote it' do
        user.update!(about_me: 'Plain text with <no> tags')
        get '/profile/edit'

        expect(inertia.props[:about]).to eq('Plain text with <no> tags')
      end

      it 'saves a name and about text without a password, and goes to the profile with a notice' do
        update_account(first_name: 'New', last_name: 'Name', about_me: 'Plain text')

        expect(response).to redirect_to('/profile')
        expect(flash[:notice]).to eq('Your account has been updated.')
        expect(user.reload).to have_attributes(first_name: 'New', last_name: 'Name', about_me: 'Plain text')
      end

      it 'comes back to the settings with the errors of an invalid name' do
        update_account(first_name: '', last_name: 'Name')

        expect(response).to redirect_to('/profile/edit')
        follow_redirect!
        expect(inertia.props[:errors]).to include(first_name: include("First name can't be blank"))
        expect(user.reload.first_name).to eq('Spec')
      end

      it 'changes the password only with the current password, and keeps the user signed in' do
        update_account(password: 'a-new-password', password_confirmation: 'a-new-password',
                       current_password: 'wrong',)
        expect(response).to redirect_to('/profile/edit')
        follow_redirect!
        expect(inertia.props[:errors]).to include(current_password: ['Current password is invalid'])
        expect(user.reload.valid_password?(DownloadFiles::PASSWORD)).to be(true)

        update_account(password: 'a-new-password', password_confirmation: 'a-new-password',
                       current_password: DownloadFiles::PASSWORD,)
        expect(response).to redirect_to('/profile')
        expect(user.reload.valid_password?('a-new-password')).to be(true)
        get '/profile'
        expect(response).to have_http_status(:ok)
      end

      # The confirmation email goes to the test mailbox: config/initializers/smtp.rb names a delivery
      # method the test environment does not have.
      around do |example|
        method = ActionMailer::Base.delivery_method
        ActionMailer::Base.delivery_method = :test
        example.run
      ensure
        ActionMailer::Base.delivery_method = method
        ActionMailer::Base.deliveries.clear
      end

      it 'holds a new email until it is confirmed, and needs the current password for it' do
        new_email = "new-#{SecureRandom.hex(4)}@example.test"

        update_account(email: new_email)
        expect(response).to redirect_to('/profile/edit')
        expect(user.reload.unconfirmed_email).to be_nil

        update_account(email: new_email, current_password: DownloadFiles::PASSWORD)
        expect(response).to redirect_to('/profile')
        expect(flash[:notice]).to eq("Account updated. Check #{new_email} to confirm your new email address.")
        expect(user.reload).to have_attributes(unconfirmed_email: new_email)
        get '/profile/edit'
        expect(inertia.props).to include(emailStatus: 'pending', unconfirmedEmail: new_email)
      end
    end
  end

  describe 'with the account page group off', page_groups: ['catalog'] do
    it 'serves the old profile page' do
      sign_in user

      get '/profile'

      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include('data-page')
      expect(response.body).to include('Edit profile')
    end
  end

  describe 'the account menu links (nav.profile, nav.settings)' do
    it 'are Inertia links while the group is on', page_groups: ['catalog', 'account'] do
      get '/resources'

      expect(inertia.props[:nav]).to include(
        profile: a_hash_including(href: '/profile', inertia: true),
        settings: a_hash_including(href: '/profile/edit', inertia: true),
      )
    end

    it 'are plain links to the old pages while it is off', page_groups: ['catalog'] do
      get '/resources'

      expect(inertia.props[:nav]).to include(
        profile: a_hash_including(href: '/profile', inertia: false),
        settings: a_hash_including(href: '/profile/edit', inertia: false),
      )
    end
  end
end
