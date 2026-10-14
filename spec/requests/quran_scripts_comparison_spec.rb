# frozen_string_literal: true

require 'rails_helper'

# P7.2: the scripts comparison tool on scripts rows. The family modes keep
# their lists (now seeded as Script meta_data); the riwayah mode puts two
# scripts side by side and lists the surah's words that separate their riwayat.
RSpec.describe 'Quran scripts comparison (P7.2)', type: :request do
  let(:warsh) { Script.find_by!(slug: 'qpc-warsh') }

  before do
    host! 'localhost' # config/initializers/hosts.rb blocks www.example.com; the tool is public, no sign-in
    Qiraat::Seed::Scripts.new.call # family / positions on the Hafs scripts
    WordDifference.delete_all
    AyahMapping.delete_all
    NumberedAyah.delete_all
    AyahNumbering.delete_all
    Qiraat::Backfill::WordNumbers.new(csv_path: QiraatFixtures.upstream('word-index.csv'), dry_run: false, logger: nil).call
    Qiraat::Import::Numberings.new(counting_path: QiraatFixtures.upstream('counting.json'), catalog_path: QiraatFixtures.upstream('catalog.json'), systems: %w[kufi madani-last], surahs: [1, 2]).call
    Qiraat::Import::AyahMappings.new.call
    Riwayah.find_by!(slug: 'warsh').update!(default_numbering: AyahNumbering.find_by!(slug: 'madani-last'))
    Qiraat::Import::WordDifferences.new(path: QiraatFixtures.upstream('differences.json'), word_index_path: QiraatFixtures.upstream('word-index.csv')).call
    forms = QiraatFixtures.word_index.select { |r| r['surah'] == '1' }.to_h { |r| [r['number'].to_i, r['form_warsh']] }
    rows = Word.unscoped.where(verse_id: Verse.where(chapter_id: 1).select(:id)).where.not(number: nil).map { |w| { script_id: warsh.id, word_id: w.id, text: forms[w.number] } }.select { |r| r[:text].present? }
    WordText.upsert_all(rows, unique_by: %i[script_id word_id])
  end

  it 'lists the Madani and Indopak scripts from the seed in the old order' do
    expect(Script.in_family('madani').count).to eq(7)
    presenter_scripts = Script.in_family('madani').select { |s| s.meta_data['charset_position'] }.sort_by { |s| s.meta_data['charset_position'] }.map(&:column_name)
    expect(presenter_scripts).to eq(%w[text_qpc_hafs text_uthmani text_digital_khatt text_digital_khatt_v1])
    compare = Script.in_family('madani').sort_by { |s| s.meta_data['compare_position'] }.map(&:comparison_key)
    expect(compare).to eq(%w[text_qpc_hafs code_v2 text_digital_khatt text_uthmani code_v1 text_digital_khatt_v1 code_v4])
    indopak = Script.in_family('indopak').sort_by { |s| s.meta_data['compare_position'] }.map(&:column_name)
    expect(indopak).to eq(%w[text_digital_khatt_indopak text_qpc_nastaleeq_hafs text_indopak text_indopak_nastaleeq text_indonesian_sign_language text_indopak_misbah])
    get '/quran_scripts_comparison?script_type=madani'
    expect(response).to have_http_status(:ok)
    expect(response.body).to include('Madani Script - Character Selection')
  end

  it 'offers the side-by-side mode from the first screen' do
    get '/quran_scripts_comparison'
    expect(response.body).to include('script_type=riwayah')
  end

  it 'shows Hafs and Warsh al-Fatihah side by side with the Warsh keys and the words that differ' do
    get '/quran_scripts_comparison?script_type=riwayah&script_a=qpc-hafs&script_b=qpc-warsh&filter_chapter=1'
    expect(response).to have_http_status(:ok)
    body = response.body
    expect(body).to include('id="ayah-1-4"')
    malik = Word.find_by!(location: '1:4:1')
    expect(body).to include("class=\"px-3 py-2 text-2xl qpc-warsh\" dir=\"rtl\">#{Verse.find_by!(verse_key: '1:4').text_for(warsh)}<")
    expect(body).to include('Warsh 1:3') # the Warsh key of Kufi 1:4
    expect(body).to include("id=\"diff-#{malik.id}\"").and include('dotting variant')
    expect(body).to include(malik.text_for(warsh))
  end

  it 'lists nothing to compare when both scripts carry the same riwayah' do
    get '/quran_scripts_comparison?script_type=riwayah&script_a=qpc-hafs&script_b=uthmani&filter_chapter=1'
    expect(response).to have_http_status(:ok)
    expect(response.body).to include('Same riwayah on both sides')
  end
end
