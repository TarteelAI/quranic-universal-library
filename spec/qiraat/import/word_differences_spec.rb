# frozen_string_literal: true

require 'rails_helper'
require 'csv'

RSpec.describe Qiraat::Import::WordDifferences do
  let(:path) { QiraatFixtures.upstream('differences.json') }

  before do
    WordDifference.delete_all
    Qiraat::Backfill::WordNumbers.new(csv_path: QiraatFixtures.upstream('word-index.csv'), dry_run: false, logger: nil).call
  end

  it 'loads every entry of the slice onto its QUL word with QUL riwayah slugs' do
    report = described_class.new(path: path).call
    expect(report[:rows]).to eq(QiraatFixtures.differences['count'] - 1) # 73950 and 73951 share one QUL row
    expect(report[:merged].size).to eq(1)
    expect(report[:unmapped]).to be_empty
    an = WordDifference.find(Word.unscoped.find_by!(location: '40:26:14').id)
    expect(an.status).to eq('rasm_variant')
    expect(an.form_for('hafs')).to eq('أَن')
    expect(an.form_for('shuba')).to eq('أَن')
    expect(an.form_for('warsh')).to eq('وَأَنْ')
    expect(an.form_for('bazzi')).to eq('وَأَن')
    expect(an.spelling_groups.map(&:last).flatten).to match_array(%w[hafs shuba bazzi qalun warsh duri susi])
    expect(an).to be_meaning_may_differ
  end

  it 'records the riwayat that do not read a word' do
    described_class.new(path: path).call
    aw = WordDifference.find(Word.unscoped.find_by!(location: '40:26:13').id)
    expect(aw.status).to eq('partial')
    expect(aw.missing).to match_array(%w[warsh qalun duri susi bazzi])
    expect(aw.form_for('warsh')).to be_nil
    expect(aw.form_for('hafs')).to eq('أَوۡ')
    expect(WordDifference.missing_in('warsh')).to include(aw)
  end

  it 'maps a word Hafs does not read and the joined pair' do
    described_class.new(path: path).call
    bazzi_only = WordDifference.find(Word.unscoped.find_by!(number: 25_685).id)
    expect(bazzi_only.missing).to include('hafs')
    expect(bazzi_only.form_for('bazzi')).to eq('مِن')
    joined = WordDifference.where(word_id: Word.unscoped.find_by!(location: '72:16:1').id)
    expect(joined.count).to eq(1) # numbers 73950 and 73951 share the row; one row per word
    expect(joined.first.written_joined).to include('hafs')
  end

  it 'is idempotent and prunes rows no longer in the file' do
    described_class.new(path: path).call
    stale = Word.unscoped.find_by!(location: '1:1:1')
    WordDifference.create!(word_id: stale.id, chapter_id: 1, status: 'alif_variant')
    report = described_class.new(path: path).call
    expect(report[:deleted]).to eq(1)
    expect(WordDifference.count).to eq(QiraatFixtures.differences['count'] - 1) # 73950/73951 collapse to one row
  end

  it 'adds the dotting variants of word-index.csv as their own status, grouped by form' do
    report = described_class.new(path: path, word_index_path: QiraatFixtures.upstream('word-index.csv')).call
    expect(report[:by_status]['dotting_variant']).to eq(1)
    expect(report[:rows]).to eq(QiraatFixtures.differences['count']) # - merged pair + the one dotting variant of the slice
    malik = WordDifference.find(Word.unscoped.find_by!(location: '1:4:1').id)
    row = CSV.read(QiraatFixtures.upstream('word-index.csv'), headers: true).find { |r| r['number'] == '11' }
    expect(malik.status).to eq('dotting_variant')
    expect(malik.form_for('hafs')).to eq(row['form_hafs'])
    expect(malik.form_for('warsh')).to eq(row['form_warsh'])
    expect(malik.form_for('susi')).to eq(row['form_susi'])
    expect(malik.spelling_groups.map { |_t, s| s.sort }).to eq([%w[hafs shuba], %w[bazzi duri qalun warsh], ['susi']])
    expect(malik.missing).to be_empty
    expect(malik).to be_meaning_may_differ
    expect(WordDifference.needs_review).to include(malik)
  end
end
