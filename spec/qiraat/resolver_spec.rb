# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Qiraat::Resolver do
  let(:counting) { QiraatFixtures.upstream('counting.json') }
  let(:catalog) { QiraatFixtures.upstream('catalog.json') }
  let(:warsh_script) { Script.find_by!(slug: 'qpc-warsh') }

  before do
    AyahMapping.delete_all
    AyahText.delete_all
    NumberedAyah.delete_all
    AyahNumbering.delete_all
    Qiraat::Backfill::WordNumbers.new(csv_path: QiraatFixtures.upstream('word-index.csv'), dry_run: false, logger: nil).call
    Qiraat::Import::Numberings.new(counting_path: counting, catalog_path: catalog, systems: %w[kufi madani-last], surahs: [1, 2]).call
    Qiraat::Import::AyahMappings.new.call
    Riwayah.find_by!(slug: 'warsh').update!(default_numbering: AyahNumbering.find_by!(slug: 'madani-last'))
    Riwayah.hafs.update!(default_numbering: AyahNumbering.kufi)
  end

  let(:warsh) { described_class.for('warsh') }
  let(:kufi) { described_class.kufi }

  it 'picks the numbering from the riwayah default' do
    expect(warsh.numbering.slug).to eq('madani-last')
    expect(described_class.for(Riwayah.hafs)).to be_kufi
  end

  it 'finds an ayah by key or by chapter and number' do
    expect(warsh.ayah('2:1').ayah_key).to eq('2:1')
    expect(warsh.ayah(1, 0)).to be_basmalah
    expect(warsh.ayah('114:1')).to be_nil # not built in this spec
  end

  it 'converts a Kufi verse forward, returning every ayah of a split' do
    expect(warsh.from_kufi('1:7').map(&:ayah_key)).to eq(%w[1:6 1:7])
    expect(warsh.from_kufi(Verse.find_by!(verse_key: '1:2')).map(&:ayah_key)).to eq(['1:1'])
    expect(warsh.from_kufi('1:1').first).to be_basmalah
    expect(warsh.relation('1:7')).to eq('split')
    expect(warsh.relation('2:1')).to eq('merged')
    expect(kufi.from_kufi('1:7').map(&:id)).to eq([Verse.find_by!(verse_key: '1:7').id])
  end

  it 'converts back, returning every Kufi verse of a merge' do
    merged = warsh.ayah('2:1')
    expect(warsh.to_kufi(merged).map(&:verse_key)).to eq(%w[2:1 2:2])
    expect(warsh.to_kufi(warsh.ayah('1:6')).map(&:verse_key)).to eq(['1:7'])
  end

  it 'does not round-trip a split losslessly, by design' do
    a6, a7 = warsh.from_kufi('1:7')
    expect(warsh.to_kufi(a6)).to eq(warsh.to_kufi(a7)) # both halves point back to Kufi 1:7
  end

  it 'gives the word range and the text in a script' do
    ayah = warsh.ayah('1:1')
    WordText.where(script_id: warsh_script.id).delete_all
    rows = ayah.words.map { |w| { script_id: warsh_script.id, word_id: w.id, text: "w#{w.position}", marks: [] } }
    WordText.upsert_all(rows, unique_by: %i[script_id word_id])
    expect(warsh.word_range(ayah).map(&:location)).to eq(%w[1:2:1 1:2:2 1:2:3 1:2:4])
    expect(warsh.text(warsh_script, ayah)).to eq('w1 w2 w3 w4')
  end

  it 'makes at most two queries per lookup' do
    verse = Verse.find_by!(verse_key: '1:2')
    numbering = warsh.numbering # memoised before counting
    queries = []
    sub = ActiveSupport::Notifications.subscribe('sql.active_record') { |*, payload| queries << payload[:sql] unless %w[SCHEMA TRANSACTION].include?(payload[:name]) }
    warsh.from_kufi(verse)
    ActiveSupport::Notifications.unsubscribe(sub)
    expect(queries.size).to be <= 2, queries.join("\n")
    expect(numbering).to be_present
  end

  describe '#content (P6.2)' do
    let(:translation_rc) { ResourceContent.create!(name: 'spec translation', sub_type: ResourceContent::SubType::Translation, cardinality_type: ResourceContent::CardinalityType::OneVerse, resource_type: 'Verse') }
    let(:wbw_rc) { ResourceContent.create!(name: 'spec wbw', sub_type: ResourceContent::SubType::Translation, cardinality_type: ResourceContent::CardinalityType::OneWord, resource_type: 'Word') }
    let(:warsh_riwayah) { Riwayah.find_by!(slug: 'warsh') }

    def translation(key, riwayah_id, text)
      Translation.new(resource_content_id: translation_rc.id, verse_id: Verse.find_by!(verse_key: key).id, language_id: 38, text: text, riwayah_id: riwayah_id).tap { |t| t.save!(validate: false) }
    end

    before do
      translation('1:4', nil, 'Master of the Day of Judgement')
      translation('1:4', warsh_riwayah.id, 'King of the Day of Judgement')
      translation('2:1', nil, 'Alif-Lam-Mim.')
      translation('2:2', nil, 'This is the Book')
      WordTranslation.new(resource_content_id: wbw_rc.id, word_id: Word.find_by!(location: '1:4:1').id, language_id: 38, text: 'master').save!(validate: false)
      WordTranslation.new(resource_content_id: wbw_rc.id, word_id: Word.find_by!(location: '1:4:1').id, language_id: 38, text: 'king', riwayah_id: warsh_riwayah.id).save!(validate: false)
    end

    it 'carries the riwayah from .for and reads its override for the ayah (Warsh 1:3 = Kufi 1:4)' do
      expect(warsh.riwayah).to eq(warsh_riwayah)
      expect(kufi.riwayah).to be_nil
      expect(warsh.content(warsh.ayah('1:3'), translation_rc).map(&:text)).to eq(['King of the Day of Judgement'])
      expect(kufi.content(kufi.ayah('1:4'), translation_rc).map(&:text)).to eq(['Master of the Day of Judgement'])
    end

    it 'returns both Kufi halves of a merged ayah, in order' do
      expect(warsh.content(warsh.ayah('2:1'), translation_rc).map(&:text)).to eq(['Alif-Lam-Mim.', 'This is the Book'])
    end

    it 'reads word glosses by the ayah words' do
      expect(warsh.content(warsh.ayah('1:3'), wbw_rc).map(&:text)).to eq(['king'])
      expect(kufi.content(kufi.ayah('1:4'), wbw_rc).map(&:text)).to eq(['master'])
    end
  end
end
