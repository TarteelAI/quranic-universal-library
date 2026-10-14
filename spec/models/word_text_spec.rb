# frozen_string_literal: true

require 'rails_helper'

RSpec.describe WordText do
  let(:script) { Script.find_by!(slug: 'qpc-hafs') }
  let(:word) { Word.unscoped.find_by!(location: '1:1:1') }

  it 'is keyed by script and word, and upserts on that key' do
    WordText.upsert_all([{ script_id: script.id, word_id: word.id, text: 'a' }], unique_by: %i[script_id word_id])
    WordText.upsert_all([{ script_id: script.id, word_id: word.id, text: 'b' }], unique_by: %i[script_id word_id])
    expect(WordText.where(script_id: script.id, word_id: word.id).count).to eq(1)
    expect(WordText.find_by!(script_id: script.id, word_id: word.id).text).to eq('b')
    expect(WordText.for_script(script).first.marks).to eq([])
  end

  it 'has an ayah_texts cache keyed the same way' do
    AyahText.upsert_all([{ script_id: script.id, ayah_id: word.verse_id, text: 'x' }], unique_by: %i[script_id ayah_id])
    expect(AyahText.for_script(script).count).to eq(1)
    expect(AyahText.find_by!(script_id: script.id, ayah_id: word.verse_id).script).to eq(script)
  end
end
