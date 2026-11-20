require 'clone_helper'
require_relative '../../support/download_files'

# Both download URLs share one code path (Catalog::DownloadsController): the slug URL
# /resources/:type/:slug/download/:file_id and the old token URL /resources/:type/:token/download.
RSpec.describe 'File downloads', type: :request do
  include DownloadFiles
  include Devise::Test::IntegrationHelpers

  routes = {
    'the slug URL' => lambda { |file|
      resource = file.downloadable_resource
      "/resources/#{resource.resource_type}/#{resource.slug}/download/#{file.id}"
    },
    'the old token URL' => ->(file) { "/resources/#{file.downloadable_resource.resource_type}/#{file.token}/download" }
  }

  let(:resource) { create_download_resource }
  let(:file) { create_download_file(resource) }

  def resource_page(file)
    resource = file.downloadable_resource
    "/resources/#{resource.resource_type}/#{resource.slug}?download=#{file.id}"
  end

  def with_forgery_protection
    original = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true
    yield
  ensure
    ActionController::Base.allow_forgery_protection = original
  end

  # The INSERT, UPDATE and DELETE statements the block runs.
  def writes_during(&block)
    statements = []
    collect = ->(*, payload) { statements << payload[:sql] if payload[:sql].match?(/\A\s*(INSERT|UPDATE|DELETE)\b/i) }
    ActiveSupport::Notifications.subscribed(collect, 'sql.active_record', &block)
    statements
  end

  routes.each do |route, path_for|
    describe route do
      %w[sign_in public].each do |mode|
        describe "in #{mode} mode", download_mode: mode do
          it 'gives 404 for an unpublished file, for everyone' do
            file.update!(published: false)

            get path_for.call(file)
            expect(response).to have_http_status(:not_found)

            sign_in create_account(role: :admin)
            get path_for.call(file)
            expect(response).to have_http_status(:not_found)
            expect(file.reload.total_download_count).to eq(0)
          end

          it 'gives 404 for a file of an unpublished resource, for everyone' do
            file
            resource.update!(published: false)

            get path_for.call(file)
            expect(response).to have_http_status(:not_found)

            sign_in create_account(role: :admin)
            get path_for.call(file)
            expect(response).to have_http_status(:not_found)
            expect(file.reload.total_download_count).to eq(0)
          end

          it 'blocks a restricted resource for an anonymous and a normal user, and sends an admin to the file' do
            restricted = create_download_file(create_download_resource(restricted: true))

            get path_for.call(restricted)
            expect(response).to have_http_status(:forbidden)

            sign_in create_account
            get path_for.call(restricted)
            expect(response).to have_http_status(:forbidden)
            expect(restricted.reload.total_download_count).to eq(0)

            sign_in create_account(role: :admin)
            get path_for.call(restricted)
            expect(response).to redirect_to(restricted.file.url)
            expect(restricted.reload.download_count).to eq(1)
          end

          it 'gives 404 for an unknown file' do
            get path_for.call(file).sub(file.token, SecureRandom.hex).sub(%r{/#{file.id}\z}, '/0')
            expect(response).to have_http_status(:not_found)
          end

          it 'marks every response noindex: the redirect, the blocked response and the 404' do
            restricted = create_download_file(create_download_resource(restricted: true))
            unpublished = create_download_file(resource, published: false)

            [file, restricted, unpublished].each do |target|
              get path_for.call(target)
              expect(response.headers['X-Robots-Tag']).to eq('noindex'), "#{response.status} #{request.path}"
            end
            expect(response).to have_http_status(:not_found)
          end

          it 'sends a signed-in user to the file and counts the per-user row, leaving the anonymous count' do
            file.update_columns(anonymous_download_count: 5)
            user = create_account
            sign_in user

            2.times do
              get path_for.call(file)
              expect(response).to redirect_to(file.file.url)
            end

            expect(file.user_downloads.where(user: user).sole.download_count).to eq(2)
            expect(file.reload.download_count).to eq(2)
            expect(file.anonymous_download_count).to eq(5)
            expect(file.total_download_count).to eq(7)
          end

          it 'counts nothing for a HEAD request' do
            sign_in create_account
            head path_for.call(file)

            expect(response).to have_http_status(:found)
            expect(file.reload.total_download_count).to eq(0)
            expect(file.user_downloads).to be_empty
          end
        end
      end

      describe 'in sign-in mode', download_mode: 'sign_in' do
        it 'with the catalog group off, sends an anonymous request to sign-in and back to the download',
           page_groups: [] do
          user = create_account
          path = path_for.call(file)

          get path
          expect(response).to redirect_to("/users/sign_in?#{{ user_return_to: path }.to_query}")

          follow_redirect!
          post '/users/sign_in', params: { user: { email: user.email, password: DownloadFiles::PASSWORD } }
          expect(response).to redirect_to(path)

          follow_redirect!
          expect(response).to redirect_to(file.file.url)
          expect(file.user_downloads.where(user: user).sole.download_count).to eq(1)
        end

        it 'with the catalog group on, sends an anonymous request to sign-in, then to the resource page, ' \
           'where the download starts', page_groups: %w[catalog] do
          user = create_account

          get path_for.call(file)
          expect(response).to redirect_to("/users/sign_in?#{{ user_return_to: resource_page(file) }.to_query}")
          expect(file.reload.total_download_count).to eq(0)

          follow_redirect!
          expect(response).to have_http_status(:ok)
          post '/users/sign_in', params: { user: { email: user.email, password: DownloadFiles::PASSWORD } }
          expect(response).to redirect_to(resource_page(file))

          get path_for.call(file)
          expect(response).to redirect_to(file.file.url)
          expect(file.user_downloads.where(user: user).sole.download_count).to eq(1)
        end

        it 'counts nothing for an anonymous HEAD request' do
          head path_for.call(file)

          expect(response).to have_http_status(:found)
          expect(file.reload.total_download_count).to eq(0)
        end
      end

      describe 'in public mode', download_mode: 'public' do
        it 'sends an anonymous GET to the file and adds exactly 1 to the anonymous count every time' do
          file.update_columns(download_count: 4)

          3.times do |i|
            get path_for.call(file)
            expect(response).to redirect_to(file.file.url)
            expect(file.reload.anonymous_download_count).to eq(i + 1)
          end
          expect(file.download_count).to eq(4)
          expect(file.total_download_count).to eq(7)
        end

        it 'adds 0 for an anonymous HEAD request' do
          head path_for.call(file)

          expect(response).to have_http_status(:found)
          expect(file.reload.anonymous_download_count).to eq(0)
        end

        it 'sets no cookie and writes nothing but the counter for an anonymous download' do
          path = path_for.call(file)
          user_downloads = UserDownload.count

          writes = with_forgery_protection do
            writes_during { get path, headers: { 'Accept' => 'text/html' } }
          end

          expect(response).to redirect_to(file.file.url)
          expect(response.headers['Set-Cookie']).to be_blank
          expect(writes.size).to eq(1)
          expect(writes.first).to match(/\AUPDATE "downloadable_files" SET "anonymous_download_count" = /)
          expect(UserDownload.count).to eq(user_downloads)
        end

        it 'sets no cookie for an anonymous visitor who already has a session from another page' do
          with_forgery_protection do
            get '/users/sign_in'
            expect(cookies.to_hash.keys).to include(Rails.application.config.session_options[:key])

            get path_for.call(file), headers: { 'Accept' => 'text/html' }
          end

          expect(response).to redirect_to(file.file.url)
          expect(response.headers['Set-Cookie']).to be_blank
          expect(file.reload.anonymous_download_count).to eq(1)
        end
      end
    end
  end

  describe 'the slug URL' do
    it 'gives 404 for an unknown slug, a wrong type and a file of another resource' do
      other = create_download_file(create_download_resource)

      get "/resources/tafsir/no-such-resource-slug/download/#{file.id}"
      expect(response).to have_http_status(:not_found)

      get "/resources/translation/#{resource.slug}/download/#{file.id}"
      expect(response).to have_http_status(:not_found)

      get "/resources/tafsir/#{resource.slug}/download/#{other.id}"
      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'robots.txt' do
    # Google's and Bing's matching: a rule is a path prefix in which `*` stands for any characters.
    def disallowed?(rules, path)
      rules.any? { |rule| path.match?(/\A#{Regexp.escape(rule).gsub('\*', '.*')}/) }
    end

    it 'disallows both download URLs for every user agent, and leaves the resource pages open' do
      get '/robots.txt'
      lines = response.body.lines.map(&:strip).reject { |line| line.empty? || line.start_with?('#') }
      group = lines.drop_while { |line| line != 'User-agent: *' }.drop(1).take_while { |l| !l.start_with?('User-agent') }
      rules = group.filter_map { |line| line.delete_prefix('Disallow:').strip if line.start_with?('Disallow:') }

      expect(disallowed?(rules, "/resources/tafsir/#{file.token}/download")).to be(true)
      expect(disallowed?(rules, "/resources/tafsir/#{resource.slug}/download/#{file.id}")).to be(true)
      expect(disallowed?(rules, "/resources/tafsir/#{resource.slug}")).to be(false)
      expect(disallowed?(rules, '/resources/tafsir')).to be(false)
    end
  end
end
