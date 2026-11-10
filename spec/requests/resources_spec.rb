require 'clone_helper'

RSpec.describe 'Resources catalog (old page)', type: :request do
  it 'lists the published resource types' do
    get '/resources'

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('href="/resources/translation"')
  end

  it 'still finds a resource by its old numeric id after the slug backfill' do
    resource = DownloadableResource.published.where(resource_type: 'translation', slug: nil).order(:id).first
    Catalog::Backfill.run

    expect(resource.reload.slug).to be_present
    get "/resources/translation/#{resource.id}"
    expect(response).to have_http_status(:ok)
    expect(response.body).to include(resource.name)

    get "/resources/translation/#{resource.slug}"
    expect(response).to have_http_status(:ok)
  end
end
