# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Qiraat::Import::Numberings do
  let(:counting) { QiraatFixtures.upstream('counting.json') }
  let(:catalog) { QiraatFixtures.upstream('catalog.json') }

  before do
    AyahNumbering.delete_all
    NumberedAyah.delete_all
    Qiraat::Backfill::WordNumbers.new(csv_path: QiraatFixtures.upstream('word-index.csv'), dry_run: false, logger: nil).call
  end

  def build(systems:, surahs: [1])
    described_class.new(counting_path: counting, catalog_path: catalog, systems: systems, surahs: surahs).call
  end

  it 'builds the Kufi numbering with rows that take the verse ids and relation same' do
    report = build(systems: ['kufi'])
    expect(report['kufi'][:ayahs]).to eq(7)
    n = AyahNumbering.kufi
    v = Verse.find_by!(verse_key: '1:1')
    a = n.ayah(1, 1)
    expect(a.id).to eq(v.id)
    expect(a.relation).to eq('same')
    expect(a.first_number).to eq(1)
    expect(a.last_number).to eq(4)
    expect(a.words.map(&:location)).to eq(%w[1:1:1 1:1:2 1:1:3 1:1:4])
    expect(n.basmalah_counted).to be(true)
    expect(n.counting_system.slug).to eq('kufi')
  end

  it 'builds the Last Madinan numbering with an unnumbered basmalah and the 1:7 split' do
    build(systems: ['madani-last'])
    n = AyahNumbering.find_by!(slug: 'madani-last')
    expect(n.basmalah_counted).to be(false)
    b = n.ayah(1, 0)
    expect(b).to be_basmalah
    expect(b.relation).to eq('unnumbered')
    expect(b.counted).to be(false)
    expect(b.words.map(&:location)).to eq(%w[1:1:1 1:1:2 1:1:3 1:1:4])
    hamd = n.ayah(1, 1)
    expect(hamd.relation).to eq('same') # same words as Kufi 1:2, numbered 1 (upstream calls this same)
    expect(hamd.kufi_verses.map(&:verse_key)).to eq(['1:2'])
    expect([n.ayah(1, 6).relation, n.ayah(1, 7).relation]).to eq(%w[split split])
    expect(n.ayah(1, 6).kufi_verses.map(&:verse_key)).to eq(['1:7'])
    expect(n.ayah(1, 7).kufi_verses.map(&:verse_key)).to eq(['1:7'])
    expect(n.numbered_ayahs.counted.count).to eq(7)
    expect(n.numbered_ayahs.counted.pluck(:ayah_index)).to eq((1..7).to_a)
  end

  it 'marks a merged ayah where one Madinan ayah spans two Kufi verses (2:1)' do
    build(systems: ['madani-last'], surahs: [1, 2])
    n = AyahNumbering.find_by!(slug: 'madani-last')
    a = n.ayah(2, 1)
    expect(a.relation).to eq('merged')
    expect(a.kufi_verses.map(&:verse_key)).to eq(%w[2:1 2:2])
  end

  it 'is idempotent' do
    build(systems: %w[kufi madani-last])
    ids = NumberedAyah.order(:numbering_id, :chapter_id, :ayah_number).pluck(:numbering_id, :ayah_key, :relation)
    build(systems: %w[kufi madani-last])
    expect(NumberedAyah.order(:numbering_id, :chapter_id, :ayah_number).pluck(:numbering_id, :ayah_key, :relation)).to eq(ids)
    expect(AyahNumbering.count).to eq(2)
  end

  it 'reports without writing on a dry run' do
    report = described_class.new(counting_path: counting, catalog_path: catalog, systems: ['kufi'], surahs: [1], dry_run: true).call
    expect(report['kufi'][:ayahs]).to eq(7)
    expect(AyahNumbering.count).to eq(0)
  end
end
