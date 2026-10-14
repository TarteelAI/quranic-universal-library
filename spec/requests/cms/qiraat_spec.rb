# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'CMS qiraat reference pages', type: :request do
  before { sign_in_admin }

  describe 'counting systems' do
    it 'lists the six systems' do
      get '/cms/counting_systems'
      expect(response).to have_http_status(:ok)
      CountingSystem::SLUGS.each { |slug| expect(response.body).to include(slug) }
    end

    it 'shows one with the qiraat attributed to it' do
      get "/cms/counting_systems/#{CountingSystem.kufi.id}"
      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Asim').and include('Hamza')
    end
  end

  describe 'qiraat' do
    it 'lists the ten readings with their riwayat' do
      get '/cms/qiraat'
      expect(response).to have_http_status(:ok)
      expect(response.body).to include('asim').and include('/cms/riwayat/')
    end

    it 'shows one with its riwayat' do
      get "/cms/qiraat/#{Qiraah.find_by!(slug: 'nafi').id}"
      expect(response).to have_http_status(:ok)
      expect(response.body).to include('qalun').and include('warsh')
    end
  end

  describe 'riwayat' do
    it 'lists all twenty and flags the unverified one' do
      get '/cms/riwayat'
      expect(response).to have_http_status(:ok)
      expect(response.body).to include('hafs').and include('idris')
      expect(response.body).to include('unverified')
    end

    it 'shows a riwayah with its mushafs' do
      get "/cms/riwayat/#{Riwayah.hafs.id}"
      expect(response).to have_http_status(:ok)
      expect(response.body).to include(Mushaf.find(5).name)
    end

    it 'toggles enabled and nothing else from the form' do
      warsh = Riwayah.find_by!(slug: 'warsh')
      patch "/cms/riwayat/#{warsh.id}", params: { riwayah: { enabled: '1', slug: 'hacked' } }
      expect(response).to redirect_to("/cms/riwayat/#{warsh.id}")
      expect(warsh.reload.enabled).to be(true)
      expect(warsh.slug).to eq('warsh')
    end

    it 'keeps the searchable select endpoint used by mushaf and recitation forms' do
      get '/cms/riwayat/all_options', params: { term: 'Haf' }
      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Hafs')
    end
  end
end
