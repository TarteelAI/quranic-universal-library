# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'CMS shared word number', type: :request do
  before do
    sign_in_admin
    Qiraat::Backfill::WordNumbers.new(csv_path: QiraatFixtures.upstream('word-index.csv'), dry_run: false, logger: nil).call
  end

  it 'filters words by shared number' do
    get '/cms/words', params: { q: { number_eq: 11 } }
    expect(response).to have_http_status(:ok)
    expect(response.body).to include('1:4:1')
  end

  it 'shows the shared number and the Hafs flag on a word' do
    get "/cms/words/#{Word.unscoped.find_by!(location: '72:16:1').id}"
    expect(response).to have_http_status(:ok)
    expect(response.body).to include('73950 – 73951').and include('covers two shared numbers')
  end

  it 'marks the word Hafs does not read' do
    get "/cms/words/#{Word.unscoped.find_by!(number: 25_685).id}"
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("another riwayah&#39;s word").or include("another riwayah's word")
  end

  it 'lists shared numbers in the verse words panel, including the non-Hafs word' do
    get "/cms/verses/#{Verse.find_by!(verse_key: '9:100').id}"
    expect(response).to have_http_status(:ok)
    expect(response.body).to include('Shared #').and include('25685')
  end
end
