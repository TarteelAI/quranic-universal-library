require 'clone_helper'

RSpec.describe 'Resources catalog (old page)', type: :request do
  it 'lists the published resource types' do
    get '/resources'

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('href="/resources/translation"')
  end
end
