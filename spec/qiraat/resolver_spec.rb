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
end
