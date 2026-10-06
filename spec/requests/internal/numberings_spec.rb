# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'internal numberings tables', type: :request do
  before do
    AyahNumbering.reset_tables!
    AyahNumbering.delete_all
    NumberedAyah.delete_all
    Qiraat::Backfill::WordNumbers.new(csv_path: QiraatFixtures.upstream('word-index.csv'), dry_run: false, logger: nil).call
    Qiraat::Import::Numberings.new(counting_path: QiraatFixtures.upstream('counting.json'), catalog_path: QiraatFixtures.upstream('catalog.json'), systems: %w[kufi madani-last], surahs: [1]).call
    host! 'localhost'
  end

  it 'returns the tables of a numbering as JSON' do
    get '/internal/numberings/madani-last'
    expect(response).to have_http_status(:ok)
    body = JSON.parse(response.body)
    expect(body['slug']).to eq('madani-last')
    expect(body['surah_ayah'].size).to eq(114)
    expect(body['surah_ayah'][0]).to eq(7)
    expect(body['first_ayah'][0]).to eq(1)
    expect(body['first_ayah'][1]).to eq(8)
    expect(body['basmalah_counted']).to be(false)
    expect(response.headers['Cache-Control']).to include('public')
  end

  it 'serves a slug with a dot' do
    AyahNumbering.find_by!(slug: 'madani-last').update!(slug: 'kfgqpc-x-v3.0')
    AyahNumbering.reset_tables!
    get '/internal/numberings/kfgqpc-x-v3.0'
    expect(response).to have_http_status(:ok)
    expect(JSON.parse(response.body)['slug']).to eq('kfgqpc-x-v3.0')
  end

  it 'is 404 for an unknown numbering' do
    get '/internal/numberings/nope'
    expect(response).to have_http_status(:not_found)
  end
end
