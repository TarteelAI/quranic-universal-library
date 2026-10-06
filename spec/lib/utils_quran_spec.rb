# frozen_string_literal: true

require 'rails_helper'

# The Kufi numbering must reproduce the ayah tables that were hard-coded in
# Ruby and JS until P4.5, exactly. The literals stay in the code only as the
# fallback for a database that has no numberings yet.
RSpec.describe Utils::Quran do
  let(:counting) { QiraatFixtures.upstream('counting.json') }
  let(:catalog) { QiraatFixtures.upstream('catalog.json') }

  before do
    described_class.reset! # class-level memo may hold the legacy fallback from an earlier example
    AyahNumbering.reset_tables!
    AyahNumbering.delete_all
    NumberedAyah.delete_all
  end

  context 'with the Kufi numbering built from counting.json (full file)' do
    before do
      # the slice counting.json has ayah_ends for the slice surahs only; the
      # tables need all 114, so this spec reads the pinned upstream file when
      # present and is skipped otherwise
      full = Rails.root.join('tmp', 'qiraat', 'upstream', 'quran-text', 'data', 'counting.json')
      skip 'run rake qiraat:fetch for the full counting.json' unless full.exist?
      Qiraat::Backfill::WordNumbers.new(csv_path: QiraatFixtures.upstream('word-index.csv'), dry_run: false, logger: nil).call
      # ayah_ends and the 114 chapter rows are enough for the tables: anchors stay nil for surahs the slice lacks words for
      Qiraat::Import::Numberings.new(counting_path: full, catalog_path: Rails.root.join('tmp/qiraat/upstream/quran-text/data/catalog.json'), systems: ['kufi']).call
      AyahNumbering.reset_tables!
    end

    it 'derives the exact legacy tables' do
      expect(AyahNumbering.kufi.surah_ayah_counts).to eq(described_class::LEGACY_SURAH_AYAH)
      expect(AyahNumbering.kufi.first_ayah_indexes).to eq(described_class::LEGACY_FIRST_AYAH)
      expect(described_class.surah_ayah).to eq(described_class::LEGACY_SURAH_AYAH)
      expect(described_class.first_ayah).to eq(described_class::LEGACY_FIRST_AYAH)
      expect(described_class.source).to eq('kufi numbering')
    end

    it 'keeps every public helper answering as before' do
      expect(described_class.get_surah_ayah_range(2)).to eq([8, 293])
      expect(described_class.get_surah_ayah_range(114)).to eq([6231, 6236])
      expect(described_class.get_ayah_key_from_id(262)).to eq('2:255')
      expect(described_class.get_ayah_id_from_key('2:255')).to eq(262)
      expect(described_class.first_ayah_of_surah?(8)).to be(true)
      expect(described_class.last_ayah_of_surah?('1:7')).to be(true)
      expect(described_class.surah_id_from_verse(6236)).to eq(114)
    end

    it 'matches the table shipped to the browser' do
      js = Rails.root.join('app/javascript/utils/quran.js').read
      table = js[/const KUFI_FIRST_AYAH = \[([^\]]+)\]/m, 1].split(',').map { |n| n.strip.to_i }
      expect(table).to eq(described_class::LEGACY_FIRST_AYAH + [6237]) # the JS table ends with total + 1 as a sentinel
    end
  end

  it 'falls back to the legacy literals when no Kufi numbering exists' do
    described_class.reset!
    expect(described_class.first_ayah).to eq(described_class::LEGACY_FIRST_AYAH)
    expect(described_class.source).to eq('legacy literals')
  end
end
