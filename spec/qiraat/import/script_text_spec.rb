# frozen_string_literal: true

require 'rails_helper'
require 'tempfile'

RSpec.describe Qiraat::Import::ScriptText do
  # A format-compatible edition file covering al-Fatihah only, built from the
  # fixture word-index forms so the text is byte-exact from upstream.
  def edition_file(key, missing: [], joined: [])
    rows = QiraatFixtures.word_index.select { |r| r['surah'] == '1' }.sort_by { |r| r['number'].to_i }
    words = []
    rows.each do |r|
      n = r['number'].to_i
      next if missing.include?(n)
      next if joined.any? { |j| j['numbers'].include?(n) && j['numbers'].first != n }

      words << r["form_#{key}"]
    end
    data = {
      'format' => 'quran-mushaf', 'format_version' => '1.0',
      'mushaf' => { 'key' => key, 'name_en' => key.capitalize, 'word_count' => words.size },
      'counting' => { 'system' => 'madani-last', 'system_printed' => 'madani-last', 'ayah_count' => 7, 'basmalah_counted' => false },
      'provenance' => { 'text' => { 'package' => "Uthmanic#{key}-v-3.0.zip", 'sha256' => 'abc', 'release_year' => 2026 } },
      'font' => { 'family' => "KFGQPC #{key} Uthmanic Script", 'file' => "#{key}.ttf", 'sha256' => 'def' },
      'words' => words,
      'numbering' => { 'total' => 77_434, 'missing' => missing, 'written_joined' => joined },
      'ayah_starts' => [4, 8, 10, 13, 17, 20, 23],
      'marks' => [[9, 0], [0, 1]],
      'mark_types' => [{ 'kind' => 'waqf', 'side' => 'after', 'sign' => 'ۖ' }, { 'kind' => 'division', 'side' => 'before', 'sign' => '۞' }]
    }
    f = Tempfile.new(["#{key}-", '.json'])
    f.write(JSON.generate(data))
    f.close
    f.path
  end

  before { Qiraat::Backfill::WordNumbers.new(csv_path: QiraatFixtures.upstream('word-index.csv'), dry_run: false, logger: nil).call }

  let(:path) { edition_file('warsh') }

  it 'creates the script row with provenance and leaves it disabled' do
    described_class.new(key: 'warsh', path: path, logger: nil).call
    s = Script.find_by!(slug: 'qpc-warsh')
    expect(s.storage).to eq('rows')
    expect(s.riwayah.slug).to eq('warsh')
    expect(s.enabled).to be(false)
    expect(s.font_css_class).to eq('qpc-warsh')
    expect(s.source_package).to eq('Uthmanicwarsh-v-3.0.zip')
    expect(s.meta_data['counting_system']).to eq('madani-last')
    expect(s.text_sha256).to match(/\A[0-9a-f]{64}\z/)
  end

  it 'writes one word_texts row per shared number with the edition form, basmalah included' do
    report = described_class.new(key: 'warsh', path: path, logger: nil).call
    s = Script.find_by!(slug: 'qpc-warsh')
    expect(report[:rows]).to eq(29)
    expect(WordText.for_script(s).count).to eq(29)
    malik = Word.unscoped.find_by!(location: '1:4:1')
    expect(WordText.find_by!(script_id: s.id, word_id: malik.id).text).to eq(QiraatFixtures.word_index_by_number[11]['form_warsh'])
    basmalah = Word.unscoped.find_by!(location: '1:1:1')
    expect(WordText.find_by(script_id: s.id, word_id: basmalah.id)).to be_present
  end

  it 'reattaches after-marks to the word and records before-marks without changing the text' do
    described_class.new(key: 'warsh', path: path, logger: nil).call
    s = Script.find_by!(slug: 'qpc-warsh')
    w10 = Word.unscoped.find_by!(number: 10) # position 9 carries the waqf sign
    expect(WordText.find_by!(script_id: s.id, word_id: w10.id).text).to end_with('ۖ')
    expect(WordText.find_by!(script_id: s.id, word_id: w10.id).marks).to eq(['ۖ'])
    w1 = Word.unscoped.find_by!(number: 1)
    expect(WordText.find_by!(script_id: s.id, word_id: w1.id).text).not_to include('۞')
    expect(WordText.find_by!(script_id: s.id, word_id: w1.id).marks).to eq(['۞'])
  end

  it 'skips numbers the edition does not read and honours a joined run' do
    path = edition_file('warsh', missing: [11], joined: [{ 'position' => 11, 'numbers' => [13, 14] }])
    report = described_class.new(key: 'warsh', path: path, logger: nil).call
    s = Script.find_by!(slug: 'qpc-warsh')
    expect(report[:missing_numbers]).to eq([11])
    expect(WordText.find_by(script_id: s.id, word_id: Word.unscoped.find_by!(number: 11).id)).to be_nil
    expect(report[:spanning_rows].map(&:first)).to eq([11]) # one printed word over two QUL rows
    expect(WordText.find_by!(script_id: s.id, word_id: Word.unscoped.find_by!(number: 13).id).text).to eq(QiraatFixtures.word_index_by_number[13]['form_warsh'])
    expect(WordText.find_by(script_id: s.id, word_id: Word.unscoped.find_by!(number: 14).id)).to be_nil
    expect(WordText.for_script(s).count).to eq(27)
  end

  it 'is idempotent and prunes rows no longer produced' do
    described_class.new(key: 'warsh', path: path, logger: nil).call
    s = Script.find_by!(slug: 'qpc-warsh')
    WordText.upsert_all([{ script_id: s.id, word_id: Word.unscoped.find_by!(location: '2:1:1').id, text: 'stale' }], unique_by: %i[script_id word_id])
    report = described_class.new(key: 'warsh', path: path, logger: nil).call
    expect(report[:deleted]).to eq(1)
    expect(WordText.for_script(s).count).to eq(29)
    expect(Script.where(slug: 'qpc-warsh').count).to eq(1)
  end

  it 'reports without writing on a dry run' do
    report = described_class.new(key: 'warsh', path: path, dry_run: true, logger: nil).call
    expect(report[:rows]).to eq(29)
    expect(Script.find_by(slug: 'qpc-warsh')).to be_nil
    expect(WordText.count).to eq(0)
  end
end
