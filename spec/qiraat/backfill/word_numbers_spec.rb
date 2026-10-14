# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Qiraat::Backfill::WordNumbers do
  let(:csv) { QiraatFixtures.upstream('word-index.csv') }

  def word(location)
    Word.unscoped.find_by!(location: location)
  end

  it 'reports without writing on a dry run' do
    Word.unscoped.update_all(number: nil, number_last: nil) # the slice ships with numbers already set
    report = described_class.new(csv_path: csv, dry_run: true, logger: nil).call
    expect(report[:numbered]).to be > 100
    expect(report[:written]).to eq(0)
    expect(Word.unscoped.where.not(number: nil)).to be_empty
  end

  context 'after a real run' do
    let!(:report) { described_class.new(csv_path: csv, dry_run: false, logger: nil).call }

    it 'aligns by position where the word counts agree' do
      expect(word('1:1:1').number).to eq(1)
      expect(word('1:4:1').number).to eq(11)       # مالك / ملك
      expect(word('40:26:13').number).to eq(60_522) # missing in five riwayat, read by Hafs
      expect(word('1:1:1').number_last).to be_nil
    end

    it 'gives one QUL row both numbers where Hafs prints two numbers as one word (72:16)' do
      w = word('72:16:1')
      expect([w.number, w.number_last]).to eq([73_950, 73_951])
      expect(report[:with_number_last]).to include('72:16:1')
    end

    it 'gives one QUL row both numbers where QUL joins two shared words (37:130)' do
      w = word('37:130:3')
      expect([w.number, w.number_last]).to eq([58_041, 58_042])
      expect(report[:text_aligned_ayahs]).to include('37:130')
    end

    it 'leaves the continuation row unnumbered where QUL splits one shared word (15:7)' do
      expect(word('15:7:1').number).to eq(33_536)
      expect(word('15:7:2').number).to be_nil
      expect(word('15:7:3').number).to eq(33_537)
      expect(report[:continuation]).to eq(['15:7:2'])
    end

    it 'never numbers ayah-end rows and reports the Bazzi-only number as having no Hafs coordinates' do
      expect(Word.unscoped.where(char_type_name: 'end').where.not(number: nil)).to be_empty
      expect(report[:index_rows_without_hafs]).to eq([25_685])
      expect(report[:unaligned_ayahs]).to be_empty
    end

    it 'is idempotent' do
      before = Word.unscoped.order(:id).pluck(:id, :number, :number_last)
      described_class.new(csv_path: csv, dry_run: false, logger: nil).call
      expect(Word.unscoped.order(:id).pluck(:id, :number, :number_last)).to eq(before)
    end
  end
end
