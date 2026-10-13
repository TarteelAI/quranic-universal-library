# frozen_string_literal: true

require 'rails_helper'

# P6.5: the translation and tafsir proofreading tools with a riwayah. Warsh
# counts Kufi 2:1 and 2:2 as one ayah (madani-last): its page shows both
# Kufi translations under the Warsh key, and an override can be written per
# Kufi verse. Without a riwayah the pages are unchanged.
RSpec.describe 'Proofreading tools with a riwayah (P6.5)', type: :request do
  let(:warsh) { Riwayah.find_by!(slug: 'warsh') }
  let(:v1) { Verse.find_by!(verse_key: '2:1') }
  let(:v2) { Verse.find_by!(verse_key: '2:2') }
  let(:v4) { Verse.find_by!(verse_key: '1:4') }
  let(:translation_rc) { ResourceContent.create!(name: 'spec translation', sub_type: ResourceContent::SubType::Translation, cardinality_type: ResourceContent::CardinalityType::OneVerse, resource_type: 'Verse', language_id: 38, language_name: 'english', approved: true) }
  let(:tafsir_rc) { ResourceContent.create!(name: 'spec tafsir', sub_type: ResourceContent::SubType::Tafsir, cardinality_type: ResourceContent::CardinalityType::OneVerse, resource_type: 'Verse', language_id: 38, language_name: 'english', approved: true) }

  def translation(verse, text, riwayah_id: nil)
    Translation.new(resource_content_id: translation_rc.id, verse_id: verse.id, language_id: 38, language_name: 'english', resource_name: 'spec translation', text: text, verse_key: verse.verse_key, chapter_id: verse.chapter_id, verse_number: verse.verse_number, riwayah_id: riwayah_id).tap { |t| t.save!(validate: false) }
  end

  before do
    sign_in_admin
    Language.create!(id: 38, name: 'English', iso_code: 'en') unless Language.exists?(38)
    AyahMapping.delete_all
    NumberedAyah.delete_all
    AyahNumbering.delete_all
    Qiraat::Backfill::WordNumbers.new(csv_path: QiraatFixtures.upstream('word-index.csv'), dry_run: false, logger: nil).call
    Qiraat::Import::Numberings.new(counting_path: QiraatFixtures.upstream('counting.json'), catalog_path: QiraatFixtures.upstream('catalog.json'), systems: %w[kufi madani-last], surahs: [1, 2]).call
    Qiraat::Import::AyahMappings.new.call
    warsh.update!(default_numbering: AyahNumbering.find_by!(slug: 'madani-last'))
    translation(v1, 'Alif-Lam-Mim.')
    translation(v2, 'This is the Book about which there is no doubt')
    translation(v4, 'Master of the Day of Judgment')
    translation(v4, 'King of the Day of Judgment', riwayah_id: warsh.id)
    Tafsir.new(resource_content_id: tafsir_rc.id, verse_id: v1.id, chapter_id: 2, language_id: 38, language_name: 'english', resource_name: 'spec tafsir', text: 'On the disjointed letters', verse_key: '2:1',
               group_verse_key_from: '2:1', group_verse_key_to: '2:2', group_verses_count: 2, start_verse_id: v1.id, end_verse_id: v2.id).save!(validate: false)
  end

  describe 'translations' do
    it 'shows both Kufi translations of the merged Warsh 2:1 under one key, with an override editor per Kufi verse' do
      get "/translation_proofreadings/#{v1.id}?resource_id=#{translation_rc.id}&riwayah=warsh"
      expect(response).to have_http_status(:ok)
      body = response.body
      expect(body).to include('Translation for Warsh 2:1')
      expect(body).to include('Alif-Lam-Mim.').and include('This is the Book about which there is no doubt')
      expect(body).to include('id="kufi-2-1"').and include('id="kufi-2-2"')
      expect(body).to include("/translation_proofreadings/#{v2.id}/override?resource_id=#{translation_rc.id}&amp;riwayah=warsh")
      expect(body).not_to include('font-medium">Warsh override') # no override exists yet (the save buttons carry the phrase)
    end

    it 'marks the Warsh override of 1:4 (Warsh 1:3) and keeps the Hafs page as before' do
      get "/translation_proofreadings/#{v4.id}?resource_id=#{translation_rc.id}&riwayah=warsh"
      expect(response.body).to include('Translation for Warsh 1:3').and include('King of the Day of Judgment').and include('Warsh override')
      get "/translation_proofreadings/#{v4.id}?resource_id=#{translation_rc.id}"
      expect(response.body).to include('Translation for 1:4').and include('Master of the Day of Judgment')
      expect(response.body).not_to include('riwayah-notice')
      expect(response.body).not_to include('King of the Day of Judgment')
    end

    it 'writes, lists and removes an override for one Kufi verse of the merged ayah' do
      put "/translation_proofreadings/#{v2.id}/override", params: { resource_id: translation_rc.id, riwayah: 'warsh', text: 'That is the Book' }
      expect(response).to redirect_to(%r{/translation_proofreadings/#{v2.id}\?.*riwayah=warsh})
      row = Translation.overrides_for(warsh).find_by!(resource_content_id: translation_rc.id, verse_id: v2.id)
      expect(row.text).to eq('That is the Book')
      expect(row.language_id).to eq(38)
      expect(row.verse_key).to eq('2:2')
      expect(Translation.shared.where(resource_content_id: translation_rc.id, verse_id: v2.id).count).to eq(1)

      get "/translation_proofreadings?resource_id=#{translation_rc.id}&riwayah=warsh&filter_chapter=2"
      expect(response.body).to include('Warsh ayah').and include('>override<')
      expect(response.body.scan('2:1').size).to be >= 2 # Kufi 2:1 and 2:2 both map to Warsh 2:1

      delete "/translation_proofreadings/#{v2.id}/remove_override", params: { resource_id: translation_rc.id, riwayah: 'warsh' }
      expect(Translation.overrides_for(warsh).where(verse_id: v2.id)).to be_empty
    end
  end

  describe 'tafsirs' do
    let(:tafsir) { Tafsir.shared.find_by!(resource_content_id: tafsir_rc.id, verse_id: v1.id) }

    it 'shows the Warsh key of the Kufi range and an override editor' do
      get "/tafsir_proofreadings/#{tafsir.id}?resource_id=#{tafsir_rc.id}&riwayah=warsh"
      expect(response).to have_http_status(:ok)
      expect(response.body).to include('2:1 - 2:2 · Warsh 2:1')
      expect(response.body).to include('On the disjointed letters').and include('no Warsh override yet')
      get "/tafsir_proofreadings/#{tafsir.id}?resource_id=#{tafsir_rc.id}"
      expect(response.body).not_to include('riwayah-notice')
    end

    it 'writes an override that keeps the Kufi grouping, and the index lists only shared rows' do
      put "/tafsir_proofreadings/#{tafsir.id}/override", params: { resource_id: tafsir_rc.id, riwayah: 'warsh', text: 'Warsh reading of the letters' }
      expect(response).to have_http_status(:redirect)
      row = Tafsir.overrides_for(warsh).find_by!(resource_content_id: tafsir_rc.id, verse_id: v1.id)
      expect([row.start_verse_id, row.end_verse_id, row.group_verse_key_to]).to eq([v1.id, v2.id, '2:2'])
      get "/tafsir_proofreadings/#{tafsir.id}?resource_id=#{tafsir_rc.id}&riwayah=warsh"
      expect(response.body).to include('Warsh reading of the letters').and include('Warsh override')
      get "/tafsir_proofreadings?resource_id=#{tafsir_rc.id}&riwayah=warsh"
      expect(response.body).to include('Warsh ayahs')
      expect(response.body.scan('Show</a>').size).to eq(1)
    end
  end
end
