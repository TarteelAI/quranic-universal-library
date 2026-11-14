# frozen_string_literal: true

require 'clone_helper'
require_relative '../../support/download_files'

# The bundle tray's lookup (/bundle?ids=…, Catalog::BundlesController): the browser holds the ids,
# and the lookup says what each is now. Resources and files are made for the spec
# (spec/support/download_files.rb).
RSpec.describe 'The bundle lookup (/bundle)', type: :request do
  include DownloadFiles
  include Devise::Test::IntegrationHelpers

  def lookup(*ids)
    get '/bundle', params: { ids: ids.join(',') }
    expect(response).to have_http_status(:ok)
    expect(response.media_type).to eq('application/json')
    response.parsed_body.deep_symbolize_keys
  end

  describe 'with the catalog page group on', page_groups: ['catalog'] do
    let(:resource) { create_download_resource }
    let!(:first_file) { create_download_file(resource) }
    let!(:hidden_file) { create_download_file(resource, published: false) }

    it "gives each id, in order, with the resource's published files and nothing private" do
      second_file = create_download_file(resource)
      body = lookup(resource.id)

      expect(response.headers['X-Robots-Tag']).to eq('noindex')
      expect(body[:items].size).to eq(1)
      item = body[:items].first
      expect(item).to include(id: resource.id, restricted: false, category: 'tafsir')
      expect(item[:resource]).to eq(id: resource.id, name: resource.display_name, type: 'tafsir',
                                    toParam: resource.to_param,)
      expect(item[:files].pluck(:id)).to eq([first_file.id, second_file.id])
      expect(item[:files].first.keys).to contain_exactly(:id, :name, :format, :formatLabel, :byteSize, :md5) # rubocop:disable Naming/VariableNumber -- md5 is the prop name
      expect(item[:files].pluck(:id)).not_to include(hidden_file.id)
    end

    it 'gives no resource for an unpublished or unknown id, and no files for a resource that lost them' do
      unpublished = create_download_resource(published: false)
      create_download_file(unpublished)
      emptied = create_download_resource
      create_download_file(emptied, published: false)
      unknown = DownloadableResource.maximum(:id) + 1000

      items = lookup(unpublished.id, resource.id, unknown, emptied.id)[:items]

      expect(items.pluck(:id)).to eq([unpublished.id, resource.id, unknown, emptied.id])
      expect(items[0]).to eq(id: unpublished.id, restricted: false, resource: nil, category: nil, files: [])
      expect(items[2]).to eq(id: unknown, restricted: false, resource: nil, category: nil, files: [])
      expect(items[3]).to include(restricted: false, files: [])
      expect(items[3][:resource][:id]).to eq(emptied.id)
    end

    it 'gives a restricted resource no files, except to an admin' do
      restricted = create_download_resource(restricted: true)
      create_download_file(restricted)

      expect(lookup(restricted.id)[:items].first).to include(restricted: true, files: [])

      sign_in create_account
      expect(lookup(restricted.id)[:items].first).to include(restricted: true, files: [])

      sign_in create_account(role: :admin)
      expect(lookup(restricted.id)[:items].first).to include(restricted: false)
      expect(lookup(restricted.id)[:items].first[:files].size).to eq(1)
    end

    it 'reads only whole positive ids, once each, at most Catalog::Bundle::MAX_IDS' do
      get '/bundle', params: { ids: "x,#{resource.id},-3,0,#{resource.id},1.5" }
      expect(response.parsed_body['items'].pluck('id')).to eq([resource.id])

      get '/bundle', params: { ids: (1..150).to_a.join(',') }
      expect(response.parsed_body['items'].size).to eq(Catalog::Bundle::MAX_IDS)

      get '/bundle'
      expect(response.parsed_body['items']).to eq([])
    end

    it 'names the download mode', download_mode: 'public' do
      expect(lookup(resource.id)[:downloadMode]).to eq('public')
    end

    it 'names the sign-in mode by default' do
      expect(lookup(resource.id)[:downloadMode]).to eq('sign_in')
    end

    it 'tells the new pages the header has the bundle tray' do
      get '/resources'
      expect(inertia.props[:nav][:bundle]).to be(true)
    end
  end

  describe 'with the catalog page group off', page_groups: ['home'] do
    it 'is a 404, and the new pages have no bundle tray' do
      get '/bundle', params: { ids: '1' }
      expect(response).to have_http_status(:not_found)

      get '/'
      expect(inertia.props[:nav][:bundle]).to be(false)
    end
  end
end
