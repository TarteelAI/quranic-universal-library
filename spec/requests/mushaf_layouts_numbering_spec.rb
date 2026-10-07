# frozen_string_literal: true

require 'rails_helper'
require Rails.root.join('lib/qiraat/layout/generator').to_s

# The layout editor on a mushaf of another numbering (P5.5): the Warsh layout
# of the fixture slice (pages 1-2) is generated first, then the editor and the
# page-range form are driven through the mushaf's own ayah keys. The Kufi
# mushaf 5 keeps its old behaviour (render parity covers the HTML).
RSpec.describe 'Mushaf layout editor across numberings', type: :request do
  before do
    sign_in_admin
    AyahMapping.delete_all
    NumberedAyah.delete_all
    AyahNumbering.delete_all
    Qiraat::Backfill::WordNumbers.new(csv_path: QiraatFixtures.upstream('word-index.csv'), dry_run: false, logger: nil).call
    Qiraat::Import::Numberings.new(counting_path: QiraatFixtures.upstream('counting.json'), catalog_path: QiraatFixtures.upstream('catalog.json'), systems: %w[kufi madani-last], surahs: [1, 2]).call
    Qiraat::Import::AyahMappings.new(numberings: ['kufi']).call
    Riwayah.find_by!(slug: 'warsh').update!(default_numbering: AyahNumbering.find_by!(slug: 'madani-last'))
    Riwayah.find_by!(slug: 'hafs').update!(default_numbering: AyahNumbering.kufi)
    Mushaf.find(5).update_columns(numbering_id: AyahNumbering.kufi.id)
    Qiraat::Layout::Generator.new(key: 'warsh', path: QiraatFixtures.upstream('mushaf-warsh.json'), csv_path: QiraatFixtures.upstream('warsh-data.csv'), logger: nil, pages_count: 604).call
    Mushaf.find(5).send(:attach_resource_content) # the editor authorises through the mushaf's resource content, absent from the fixture slice
  end

  let(:warsh) { Mushaf.find_by!(script: Script.find_by!(slug: 'qpc-warsh'), layout_source: 'generated') }

  it 'lists page 1 of the Warsh mushaf by its numbered ayahs, basmalah unnumbered, markers keyed by their rows' do
    get "/mushaf_layouts/#{warsh.id}/edit?page_number=1"
    expect(response).to have_http_status(:ok)
    body = response.body
    expect(body.scan(/<span class="word-group"> (\d+:\d+)<\/span>/).flatten).to eq(%w[1:0 1:1 1:2 1:3 1:4 1:5 1:6 1:7])
    # the Warsh ayah 1:1 ends on the Kufi end of 1:2, so its marker is that words row; the basmalah row has no marker
    end_row = Word.unscoped.find_by!(verse_id: Verse.find_by!(verse_key: '1:2').id, char_type_id: CharType.find_by!(name: 'end').id)
    expect(body).to include("name=\"layout[words][#{end_row.id}][line_number]\"")
    expect(body).to include('1:0 - 1:7')
    # Warsh 1:6 ends inside Kufi 1:7 (madani-last splits it), so its marker has no words row and is keyed by its own row
    split = MushafWord.where(mushaf_id: warsh.id, page_number: 1, char_type_name: 'end', word_id: nil).first
    expect(split.ayah.ayah_key).to eq('1:6')
    expect(body).to include("name=\"layout[words][mw#{split.id}][line_number]\"")
    expect(body).to include('1:6 end')
  end

  it 'keys a marker by its mushaf_words row when it has no words row (page 2, forced)' do
    marker = MushafWord.where(mushaf_id: warsh.id, page_number: 2, char_type_name: 'end').first
    expect(marker.word_id).to be_present # 2:1 ends on the Kufi end of 2:2
    marker.update_columns(word_id: nil) # pretend it is a mid-verse end to exercise the mw key
    get "/mushaf_layouts/#{warsh.id}/edit?page_number=2"
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("name=\"layout[words][mw#{marker.id}][line_number]\"")
  end

  it 'saves a page range typed in the mushaf numbering and keeps the Kufi range in step' do
    put "/mushaf_layouts/#{warsh.id}/save_page_mapping?page_number=1", params: { mushaf_page: { first_verse_id: '1:0', last_verse_id: '1:7' } }
    page = MushafPage.find_by!(mushaf_id: warsh.id, page_number: 1)
    expect(page.first_ayah.ayah_key).to eq('1:0')
    expect(page.last_ayah.ayah_key).to eq('1:7')
    expect(page.first_verse.verse_key).to eq('1:1')
    expect(page.last_verse.verse_key).to eq('1:7')
    expect(page.first_ayah_key).to eq('1:0')
  end

  it 'finds a page by an ayah key in the mushaf numbering' do
    get "/mushaf_layouts/#{warsh.id}?search=2:1"
    expect(response).to have_http_status(:ok)
    expect(response.body).to include('id="page-row-2"')
    expect(response.body).not_to include('id="page-row-1"')
  end

  it 'keeps the Kufi mushaf on Kufi keys' do
    put '/mushaf_layouts/5/save_page_mapping?page_number=1', params: { mushaf_page: { first_verse_id: '1:1', last_verse_id: '1:7' } }
    page = MushafPage.find_by!(mushaf_id: 5, page_number: 1)
    expect(page.first_verse_id).to eq(Verse.find_by!(verse_key: '1:1').id)
    expect(page.first_ayah_id).to eq(page.first_verse_id)
    get '/mushaf_layouts/5/edit?page_number=1'
    expect(response).to have_http_status(:ok)
    expect(response.body).to include('name="layout[words][1][line_number]"')
  end
end
