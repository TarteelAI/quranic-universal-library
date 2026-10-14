# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'text through scripts (P3.4)' do
  let(:qpc_hafs) { Script.find_by!(slug: 'qpc-hafs') }
  let(:qpc_v1) { Script.find_by!(slug: 'qpc-v1') }
  let(:word) { Word.unscoped.find_by!(location: '1:4:1') }
  let(:verse) { word.verse }
  let(:mushaf) { Mushaf.find(5) }

  describe Word, '#text_for' do
    it 'reads a column-backed script from the column' do
      expect(word.text_for(qpc_hafs)).to eq(word.text_qpc_hafs)
      expect(word.text_for(qpc_v1)).to eq(word.code_v1)
    end

    it 'reads a row-backed script from word_texts and returns nil where the riwayah does not read the word' do
      warsh = Script.create!(slug: 'spec-warsh', name: 'Warsh', riwayah: Riwayah.find_by!(slug: 'warsh'), storage: 'rows', kind: 'unicode')
      WordText.upsert_all([{ script_id: warsh.id, word_id: word.id, text: 'مَلِكِ' }], unique_by: %i[script_id word_id])
      expect(word.text_for(warsh)).to eq('مَلِكِ')
      expect(Word.unscoped.find_by!(location: '1:1:1').text_for(warsh)).to be_nil
    end
  end

  describe Verse, '#text_for' do
    it 'reads a column-backed script from the verse column' do
      expect(verse.text_for(qpc_hafs)).to eq(verse.text_qpc_hafs)
    end

    it 'joins word_texts for a row-backed script until ayah_texts is filled' do
      warsh = Script.create!(slug: 'spec-warsh', name: 'Warsh', riwayah: Riwayah.find_by!(slug: 'warsh'), storage: 'rows', kind: 'unicode')
      rows = verse.all_words.select { |w| w.char_type_name == 'word' }.map { |w| { script_id: warsh.id, word_id: w.id, text: "w#{w.position}" } }
      WordText.upsert_all(rows, unique_by: %i[script_id word_id])
      expected = verse.all_words.select { |w| w.char_type_name == 'word' }.map { |w| "w#{w.position}" }.join(' ')
      expect(verse.text_for(warsh)).to eq(expected) # 1:4 has three words
    end
  end

  describe Mushaf do
    it 'derives text_type_method, glyph and image flags from its script when set' do
      mushaf.update_column(:script_id, qpc_v1.id)
      mushaf.reload
      expect(mushaf.text_type_method).to eq('code_v1')
      expect(mushaf.using_glyphs?).to be(true)
      expect(mushaf.use_images?).to be(false)
      mushaf.update_column(:script_id, Script.find_by!(slug: 'black-images').id)
      expect(mushaf.reload.use_images?).to be(true)
    end

    it 'falls back to the legacy name matching without a script; glyphs only come from a script (P7.5)' do
      mushaf.update_column(:script_id, nil)
      expect(mushaf.reload.text_type_method).to eq('text_qpc_hafs') # name "KFGQPC HAFS"
      expect(Mushaf.new(id: 1, name: 'x').using_glyphs?).to be(false)
      expect(mushaf.using_glyphs?).to be(false)
    end
  end

  describe Word, '#text_for_mushaf' do
    it 'uses the mushaf script, then the cached mushaf word, then the legacy map' do
      mushaf.update_column(:script_id, qpc_hafs.id)
      expect(word.text_for_mushaf(mushaf.id)).to eq(word.text_qpc_hafs)
      mushaf.update_column(:script_id, nil)
      expect(word.text_for_mushaf(mushaf.id)).to eq(word.text_qpc_hafs) # legacy constant: 5 => text_qpc_hafs
    end
  end

  describe Word, 'cache refresh on update' do
    it 'fans a column change out to every mushaf whose script reads that column, and no other' do
      mushaf.update_column(:script_id, qpc_hafs.id)
      other = Mushaf.create!(name: 'spec other', riwayah: Riwayah.hafs, pages_count: 604, lines_per_page: 15, script: qpc_v1)
      mw_other = MushafWord.create!(mushaf: other, word: word, verse: verse, char_type_id: word.char_type_id, text: 'untouched', page_number: 1, line_number: 1, position_in_page: 1, position_in_line: 1, position_in_verse: 1)
      mw = MushafWord.find_by!(mushaf_id: mushaf.id, word_id: word.id)
      word.update!(text_qpc_hafs: 'مَٰلِكِX')
      expect(mw.reload.text).to eq('مَٰلِكِX')
      expect(mw_other.reload.text).to eq('untouched')
      expect(verse.reload.text_qpc_hafs).to include('مَٰلِكِX')
    end
  end
end
