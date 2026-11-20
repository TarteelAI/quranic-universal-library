# frozen_string_literal: true

require 'clone_helper'
require_relative '../../support/download_files'

# The CMS names a resource by its plain `name`. ActiveAdmin labels a record with `display_name`
# first, so the model must not answer it: the computed display name loads the whole catalog.
RSpec.describe 'Downloadable resources in the CMS (/cms/downloadable_resources)', type: :request do
  include DownloadFiles
  include Devise::Test::IntegrationHelpers

  let(:resource) { DownloadableResource.where.not(name: [nil, '']).first }

  before { sign_in create_account(role: :super_admin) }

  it 'labels a resource with its name without loading the catalog' do
    expect(resource).not_to respond_to(:display_name)
    expect(Catalog::Derived).not_to receive(:current)

    get "/cms/downloadable_resources/#{resource.id}"
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("<title>#{ERB::Util.html_escape(resource.name)}")

    get '/cms/downloadable_files', params: { q: { downloadable_resource_id_eq: resource.id } }
    expect(response).to have_http_status(:ok)
  end
end
