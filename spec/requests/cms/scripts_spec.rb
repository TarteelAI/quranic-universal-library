# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'CMS scripts, word texts and differences', type: :request do
  let(:csv) { QiraatFixtures.upstream('word-index.csv') }
  let!(:warsh) { Script.find_by!(slug: 'qpc-warsh') }

  before do
    sign_in_admin
    Qiraat::Backfill::WordNumbers.new(csv_path: csv, dry_run: false, logger: nil).call
    WordText.upsert_all([{ script_id: warsh.id, word_id: Word.unscoped.find_by!(location: '1:4:1').id, text: 'مَلِكِ' }], unique_by: %i[script_id word_id])
    Qiraat::Import::WordDifferences.new(path: QiraatFixtures.upstream('differences.json')).call
  end

  it 'lists scripts with storage and riwayah and shows one with its sample' do
    get '/cms/scripts'
    expect(response).to have_http_status(:ok)
    expect(response.body).to include('qpc-hafs').and include('qpc-warsh').and include('rows')
    get "/cms/scripts/#{warsh.id}"
    expect(response).to have_http_status(:ok)
    expect(response.body).to include('al-Fatihah 1:1 in this script').and include('Warsh')
  end

  it 'lists word texts filtered by script and verse key' do
    get '/cms/word_texts', params: { q: { script_id_eq: warsh.id, word_verse_key_cont: '1:4' } }
    expect(response).to have_http_status(:ok)
    expect(response.body).to include('مَلِكِ').and include('1:4:1')
  end

  it 'lists and shows word differences with spellings per riwayah' do
    get '/cms/word_differences', params: { q: { status_eq: 'partial' } }
    expect(response).to have_http_status(:ok)
    expect(response.body).to include('40:26:13')
    d = WordDifference.find(Word.unscoped.find_by!(location: '40:26:14').id)
    get "/cms/word_differences/#{d.word_id}"
    expect(response).to have_http_status(:ok)
    expect(response.body).to include('وَأَنْ').and include('qalun, warsh')
  end

  it 'shows the forms in other riwayat on the word page' do
    get "/cms/words/#{Word.unscoped.find_by!(location: '1:4:1').id}"
    expect(response).to have_http_status(:ok)
    expect(response.body).to include('Forms in other riwayat').and include('qpc-warsh')
    get "/cms/words/#{Word.unscoped.find_by!(location: '40:26:13').id}"
    expect(response.body).to include('Listed in word differences')
  end

  it 'keeps ayah texts reachable (empty until phase 4)' do
    get '/cms/ayah_texts'
    expect(response).to have_http_status(:ok)
  end
end
