# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Qiraat::Backfill::MissingWords do
  let(:csv) { QiraatFixtures.upstream('word-index.csv') }

  before do
    # The slice is generated from a dev database where the row already exists;
    # start from the pre-insert state so the backfill is exercised for real.
    Word.unscoped.where(hafs_reads: false).delete_all
    Qiraat::Backfill::WordNumbers.new(csv_path: csv, dry_run: false, logger: nil).call
  end

  it 'finds the one number without Hafs coordinates and places it after 9:100:17 on a dry run' do
    report = described_class.new(csv_path: csv, dry_run: true).call
    expect(report[:candidates]).to eq([25_685])
    expect(report[:inserted].map(&:to_h)).to eq([{ number: 25_685, location: '9:100:17.1', verse_key: '9:100', after_location: '9:100:17' }])
    expect(Word.unscoped.find_by(number: 25_685)).to be_nil
  end

  context 'after inserting' do
    before { described_class.new(csv_path: csv, dry_run: false).call }

    let(:row) { Word.unscoped.find_by!(number: 25_685) }
    let(:verse) { Verse.find_by!(verse_key: '9:100') }

    it 'creates a word row Hafs does not read, ordered after its neighbour' do
      expect(row.verse_id).to eq(verse.id)
      expect(row.position).to eq(17)
      expect(row.sub_position).to eq(1)
      expect(row.hafs_reads).to be(false)
      expect(row.char_type_name).to eq('word')
      expect(row.text_qpc_hafs).to be_nil
      ordered = Word.where(verse_id: verse.id).to_a # default scope orders by position, sub_position
      expect(ordered.index(row)).to eq(ordered.index(Word.unscoped.find_by!(location: '9:100:17')) + 1)
    end

    it 'is hidden from Hafs paths: verse.words, Word.hafs' do
      expect(verse.words.map(&:location)).not_to include('9:100:17.1')
      expect(verse.words.count).to eq(Word.unscoped.where(verse_id: verse.id, hafs_reads: true).count)
      expect(Word.hafs.where(number: 25_685)).to be_empty
      expect(Word.unscoped.where(number: 25_685).count).to eq(1)
    end

    it 'is idempotent' do
      report = described_class.new(csv_path: csv, dry_run: false).call
      expect(report[:inserted]).to be_empty
      expect(report[:already_present]).to eq(['9:100:17.1'])
      expect(Word.unscoped.where(number: 25_685).count).to eq(1)
    end
  end
end
