# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'numbering tables (P4.1)' do
  let(:kufi) { CountingSystem.kufi }
  let(:v1) { Verse.find_by!(verse_key: '2:1') }
  let(:v2) { Verse.find_by!(verse_key: '2:2') }

  it 'stores a numbering, its ayahs and a forward mapping with the expected keys' do
    n = AyahNumbering.create!(slug: 'spec-madani', kind: 'madhhab', counting_system: CountingSystem.find_by!(slug: 'madani-last'), basmalah_counted: false)
    first = v1.words.first
    last = v2.words.where(char_type_name: 'word').last
    a = n.numbered_ayahs.create!(chapter_id: 2, ayah_number: 1, ayah_key: '2:1', ayah_index: 1, first_word: first, last_word: last,
                                 first_number: first.number, last_number: last.number,
                                 kufi_first_verse: v1, kufi_last_verse: v2, relation: 'merged')
    expect(n.ayah(2, 1)).to eq(a)
    expect(a.kufi_verses).to eq([v1, v2])
    expect(a.words.first).to eq(first)
    expect(a.words.last).to eq(last)
    expect(a.words.count).to eq(v1.words.where(char_type_name: 'word').count + v2.words.where(char_type_name: 'word').count)
    expect(n.surah_counts).to eq({ 2 => 1 })

    AyahMapping.create!(numbering: n, verse: v1, ayah: a, relation: 'merged', merges_with_next: true)
    AyahMapping.create!(numbering: n, verse: v2, ayah: a, relation: 'merged')
    m = AyahMapping.find_by!(numbering_id: n.id, verse_id: v2.id)
    expect(m.ayahs).to eq([a])
    expect(m).not_to be_split
    expect { n.numbered_ayahs.create!(chapter_id: 2, ayah_number: 1, ayah_key: '2:1') }.to raise_error(ActiveRecord::RecordNotUnique)
  end

  it 'allows an unnumbered basmalah as ayah 0' do
    n = AyahNumbering.create!(slug: 'spec-madani', kind: 'madhhab')
    b = n.numbered_ayahs.create!(chapter_id: 1, ayah_number: 0, ayah_key: '1:0', counted: false, relation: 'unnumbered')
    expect(b).to be_basmalah
    expect(n.numbered_ayahs.counted).to be_empty
  end

  it 'rejects unknown kinds and relations' do
    expect { AyahNumbering.create!(slug: 'x', kind: 'guess') }.to raise_error(ActiveRecord::RecordInvalid)
    n = AyahNumbering.create!(slug: 'spec', kind: 'printed')
    expect { n.numbered_ayahs.create!(chapter_id: 1, ayah_number: 1, ayah_key: '1:1', relation: 'nope') }.to raise_error(ActiveRecord::RecordInvalid)
  end
end
