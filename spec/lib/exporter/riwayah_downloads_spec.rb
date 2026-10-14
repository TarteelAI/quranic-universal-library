# frozen_string_literal: true

require 'rails_helper'
require Rails.root.join('lib/exporter/export_riwayah_text').to_s
require Rails.root.join('lib/exporter/export_ayah_numbering_map').to_s

# P7.4: the downloads of a riwayah's text and of the ayah numbering map.
# Warsh word forms of al-Fatihah come from the fixture word index.
RSpec.describe 'riwayah downloads (P7.4)' do
  let(:warsh) { Script.find_by!(slug: 'qpc-warsh') }
  let(:base_path) { Dir.mktmpdir('riwayah-export') }

  before do
    AyahMapping.delete_all
    NumberedAyah.delete_all
    AyahNumbering.delete_all
    Qiraat::Backfill::WordNumbers.new(csv_path: QiraatFixtures.upstream('word-index.csv'), dry_run: false, logger: nil).call
    Qiraat::Import::Numberings.new(counting_path: QiraatFixtures.upstream('counting.json'), catalog_path: QiraatFixtures.upstream('catalog.json'), systems: %w[kufi madani-last], surahs: [1, 2]).call
    Qiraat::Import::AyahMappings.new.call
    Riwayah.find_by!(slug: 'warsh').update!(default_numbering: AyahNumbering.find_by!(slug: 'madani-last'))
    forms = QiraatFixtures.word_index.select { |r| r['surah'] == '1' }.to_h { |r| [r['number'].to_i, r['form_warsh']] }
    rows = Word.unscoped.where(verse_id: Verse.where(chapter_id: 1).select(:id)).where.not(number: nil).map { |w| { script_id: warsh.id, word_id: w.id, text: forms[w.number] } }.select { |r| r[:text].present? }
    WordText.upsert_all(rows, unique_by: %i[script_id word_id])
  end

  after { FileUtils.rm_rf(base_path) }

  describe Exporter::ExportRiwayahText do
    let(:exporter) { described_class.new(script: warsh, base_path: base_path) }

    it 'exports the ayahs in the Warsh numbering with their Kufi range and text' do
      dir = exporter.export('ayah', 'json')
      data = JSON.parse(File.read("#{dir}/ayah.json"))
      fatihah = data.values.select { |a| a['surah'] == 1 }
      expect(fatihah.map { |a| a['key'] }).to eq(%w[1:0 1:1 1:2 1:3 1:4 1:5 1:6 1:7])
      expect(fatihah.first['counted']).to be(false) # the basmalah, unnumbered in Warsh
      expect(data['1:3'].values_at('kufi_from', 'kufi_to')).to eq(%w[1:4 1:4])
      expect(data['1:3']['relation']).to eq(AyahMapping.find_by!(numbering: AyahNumbering.find_by!(slug: 'madani-last'), verse: Verse.find_by!(verse_key: '1:4')).relation)
      expect(data['1:3']['text']).to include(Word.find_by!(location: '1:4:1').text_for(warsh))
      expect(data['1:7'].values_at('kufi_from', 'kufi_to')).to eq(%w[1:7 1:7])
      expect(File.read("#{dir}/README.md")).to include(warsh.licence.to_s).and include('madani-last')
      sqlite = exporter.export('ayah', 'sqlite')
      db = SQLite3::Database.new("#{sqlite}/ayah.sqlite")
      expect(db.execute('select count(*) from ayahs').first.first).to eq(data.size)
      expect(db.execute("select text from ayahs where key = '1:3'").first.first).to eq(data['1:3']['text'])
      db.close
    end

    it 'exports the words by shared number with their Warsh ayah and Kufi location' do
      dir = exporter.export('word', 'json')
      data = JSON.parse(File.read("#{dir}/word.json"))
      expect(data.size).to eq(WordText.where(script_id: warsh.id).count)
      malik = data.find { |_k, w| w['kufi_location'] == '1:4:1' }.last
      expect(malik.values_at('number', 'key', 'word')).to eq([Word.find_by!(location: '1:4:1').number, '1:3', 1])
      expect(malik['text']).to eq(Word.find_by!(location: '1:4:1').text_for(warsh))
      expect(data.keys.map(&:to_i)).to eq(data.keys.map(&:to_i).sort) # in number order
      expect(File.exist?("#{dir}/README.md")).to be(true)
    end
  end

  describe Exporter::ExportAyahNumberingMap do
    let(:exporter) { described_class.new(base_path: base_path) }

    it 'maps every Kufi verse of the slice to its madani-last ayah with the relation, as JSON and CSV' do
      dir = exporter.export('json')
      data = JSON.parse(File.read("#{dir}/ayah-map.json"))
      expect(data['reference']).to eq('kufi')
      expect(data['numberings'].map { |n| n['slug'] }).to include('madani-last')
      by_key = data['ayahs'].index_by { |a| a['verse_key'] }
      expect(by_key['1:1']['madani-last']).to eq('surah' => 1, 'ayah' => 0, 'relation' => 'unnumbered')
      expect(by_key['1:7']['madani-last']).to include('ayah' => 6, 'ayah_last' => 7, 'relation' => 'split')
      expect(by_key['2:1']['madani-last']).to include('ayah' => 1, 'relation' => 'merged')
      csv = CSV.read("#{exporter.export('csv')}/ayah-map.csv", headers: true)
      expect(csv.headers).to include('madani-last_ayah', 'madani-last_relation')
      expect(csv.find { |r| r['verse_id'] == Verse.find_by!(verse_key: '1:7').id.to_s }['madani-last_ayah']).to eq('1:6-7')
      expect(File.read("#{dir}/README.md")).to include('CC BY 4.0')
    end
  end

  it 'registers the two download types' do
    expect(DownloadableResource::RESOURCE_TYPES).to include('riwayah-text', 'ayah-numbering')
  end
end
