# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Qiraat::Seed::LegacyScripts do
  let(:hafs) { Riwayah.hafs }
  let(:warsh) { Riwayah.find_by!(slug: 'warsh') }
  let(:verse) { Verse.find_by!(verse_key: '1:2') }

  before do
    Script.where(storage: 'legacy').delete_all
    QuranScript::ByVerse.delete_all
    QuranScript::ByWord.delete_all
    @ayah_rc = ResourceContent.create!(name: 'Quran Script(Warsh) - Ayah by Ayah', sub_type: ResourceContent::SubType::QuranText, cardinality_type: ResourceContent::CardinalityType::OneVerse, meta_data: { 'font-face' => 'qpc-warsh', 'qirat' => 'Warsh' })
    @word_rc = ResourceContent.create!(name: 'Quran Script(Warsh) - Word by Word', sub_type: ResourceContent::SubType::QuranText, cardinality_type: ResourceContent::CardinalityType::OneWord)
    @madani = ResourceContent.create!(name: 'Madani script', sub_type: ResourceContent::SubType::QuranText)
    @simple = ResourceContent.create!(name: 'Simple script', sub_type: ResourceContent::SubType::QuranText)
    QuranScript::ByVerse.create!(resource_content_id: @ayah_rc.id, qirat_id: warsh.id, chapter_id: 1, verse_number: 1, key: '1:1', text: 'ࡴ۬لْحَمْدُ لِلهِ رَبِّ ࡴ۬لْعَٰلَمِينَ')
    QuranScript::ByWord.create!(resource_content_id: @word_rc.id, qirat_id: warsh.id, chapter_id: 1, verse_number: 1, word_number: 1, key: '1:1:1', text: 'ࡴ۬لْحَمْدُ')
    QuranScript::ByVerse.create!(resource_content_id: @madani.id, qirat_id: hafs.id, chapter_id: 1, verse_number: 2, key: '1:2', verse_id: verse.id, text: 'madani')
    QuranScript::ByVerse.create!(resource_content_id: @simple.id, qirat_id: hafs.id, chapter_id: 1, verse_number: 2, key: '1:2', verse_id: verse.id, text: 'simple')
  end

  it 'makes one legacy script per riwayah pairing ayah and word resources, and one per unpaired resource' do
    report = described_class.new.call
    expect(report[:created]).to eq(3)
    legacy = Script.where(storage: 'legacy')
    w = legacy.find_by!(slug: 'legacy-warsh')
    expect(w.ayah_resource_content_id).to eq(@ayah_rc.id)
    expect(w.word_resource_content_id).to eq(@word_rc.id)
    expect(w.font_css_class).to eq('qpc-warsh')
    expect(w.riwayah).to eq(warsh)
    expect(w).to be_enabled
    expect(legacy.where(riwayah_id: hafs.id).pluck(:slug)).to match_array(%w[legacy-hafs-madani-script legacy-hafs-simple-script])
  end

  it 'reads legacy text by Kufi key through text_for' do
    described_class.new.call
    madani = Script.find_by!(slug: 'legacy-hafs-madani-script')
    expect(verse.text_for(madani)).to eq('madani')
    w = Script.find_by!(slug: 'legacy-warsh')
    expect(Word.unscoped.find_by!(location: '1:1:1').text_for(w)).to eq('ࡴ۬لْحَمْدُ')
    expect(Verse.find_by!(verse_key: '1:1').text_for(w)).to eq('ࡴ۬لْحَمْدُ لِلهِ رَبِّ ࡴ۬لْعَٰلَمِينَ') # Kufi 1:1 is the basmalah; Warsh key 1:1 is al-hamd: a legacy key, not a mapping
  end

  it 'is idempotent' do
    described_class.new.call
    ids = Script.where(storage: 'legacy').order(:id).pluck(:id, :slug)
    report = described_class.new.call
    expect(report[:created]).to eq(0)
    expect(Script.where(storage: 'legacy').order(:id).pluck(:id, :slug)).to eq(ids)
  end

  it 'exposes the script for a resource content so exporters pick the right source' do
    described_class.new.call
    expect(Script.for_resource_content(@word_rc).slug).to eq('legacy-warsh')
    expect(Script.for_resource_content(@ayah_rc).slug).to eq('legacy-warsh')
    expect(Script.for_resource_content(@madani).slug).to eq('legacy-hafs-madani-script')
  end
end
