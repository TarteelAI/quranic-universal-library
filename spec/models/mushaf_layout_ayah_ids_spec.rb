# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'mushaf layout ayah ids (P5.2)' do
  let(:mushaf) { Mushaf.find(5) }

  before do
    AyahMapping.delete_all
    NumberedAyah.delete_all
    AyahNumbering.delete_all
    Qiraat::Backfill::WordNumbers.new(csv_path: QiraatFixtures.upstream('word-index.csv'), dry_run: false, logger: nil).call
    Qiraat::Import::Numberings.new(counting_path: QiraatFixtures.upstream('counting.json'), catalog_path: QiraatFixtures.upstream('catalog.json'), systems: ['kufi'], surahs: [1, 2]).call
    Qiraat::Import::AyahMappings.new(numberings: ['kufi']).call
    mushaf.update_columns(numbering_id: AyahNumbering.kufi.id)
    MushafWord.where(mushaf_id: mushaf.id).update_all(ayah_id: nil)
  end

  it 'lets an ayah-end marker exist without a words row, and links a word to its numbered ayah' do
    verse = Verse.find_by!(verse_key: '1:1')
    marker = MushafWord.create!(mushaf: mushaf, word: nil, verse: verse, ayah_id: verse.id, char_type_id: CharType.find_by!(name: 'end').id,
                                char_type_name: 'end', text: '١', page_number: 1, line_number: 2, position_in_page: 99, position_in_line: 5, position_in_verse: 5)
    expect(marker.word).to be_nil
    expect(marker.ayah).to eq(NumberedAyah.find(verse.id))
    expect(marker.ayah.ayah_key).to eq('1:1')
  end

  it 'builds one verse_mapping shape with range and count per chapter' do
    v1 = Verse.find_by!(verse_key: '1:1')
    v2 = Verse.find_by!(verse_key: '2:3')
    map = MushafPage.build_verse_mapping(v1.id, v2.id)
    expect(map.keys).to match_array([1, 2].map { |n| Chapter.find_by!(chapter_number: n).id })
    expect(map.values.first).to eq({ range: '1-7', count: 7 })
    expect(map.values.last[:count]).to eq(3)
  end

  it 'fills the page ayah range from its words when stats are rebuilt' do
    page = MushafPage.find_by!(mushaf_id: mushaf.id, page_number: 1)
    MushafWord.where(mushaf_id: mushaf.id, page_number: 1).find_each { |mw| mw.update_columns(ayah_id: mw.verse_id) }
    page.update_columns(first_ayah_id: nil, last_ayah_id: nil)
    mushaf.update_pages_stats
    page.reload
    expect(page.first_ayah_id).to eq(page.first_verse_id)
    expect(page.last_ayah_id).to eq(page.last_verse_id)
    expect(page.first_ayah).to be_a(NumberedAyah)
    expect(page.verse_mapping.values.first).to include('range', 'count')
  end
end
