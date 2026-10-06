# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Riwayah test setup' do
  it 'runs Quran-side models against quran_test, never the dev copy' do
    expect(Verse.connection.current_database).to eq('quran_test')
    expect(ActiveRecord::Base.connection.current_database).to eq('quran_community_cms_test')
  end

  it 'loads the fixture slice' do
    expect(Chapter.count).to eq(5)
    expect(Verse.count).to eq(14)
    expect(Verse.find_by(verse_key: '2:255')).to be_present
    expect(Word.unscoped.where(verse_id: Verse.find_by(verse_key: '1:1').id, char_type_name: 'word').count).to eq(4)
    expect(MushafWord.where(mushaf_id: 5).count).to be > 0
  end

  it 'carries the upstream reference rows for the edge cases' do
    idx = QiraatFixtures.word_index_by_number
    expect(idx[11]['hafs_surah']).to eq('1')
    expect(idx[11]['hafs_ayah']).to eq('4')
    expect(idx[25685]['hafs_surah']).to be_blank   # read only by Bazzi
    expect(idx[73950]['hafs_ayah']).to eq('16')    # Hafs writes 73950 and 73951 as one word
    expect(idx[73951]['hafs_ayah']).to eq('16')

    entry = QiraatFixtures.ayah_map['ayahs'].find { |e| e['surah'] == 2 && e['ayah'] == 255 }
    expect(entry['warsh']['relation']).to eq('split')
    expect(entry['warsh']['ayah_last']).to eq(254)

    expect(QiraatFixtures.qiraat.keys).to include('asim', 'nafi', 'ibn-kathir')
    expect(QiraatFixtures.counting_systems['kufi']['is_reference']).to be(true)
  end
end
