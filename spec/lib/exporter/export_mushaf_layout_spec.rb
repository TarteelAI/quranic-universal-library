# frozen_string_literal: true

require 'rails_helper'
require Rails.root.join('lib/qiraat/layout/generator').to_s

# P5.7: the layout export carries the riwayah, the numbering, the face and,
# per line, the shared word numbers and ayah keys — added after the columns
# the existing Hafs consumers read. The fixture slice already has
# mushaf_words.ayah_id for mushaf 5 (P5.2).
RSpec.describe Exporter::ExportMushafLayout do
  let(:base_path) { Dir.mktmpdir('layout-export') }

  before do
    AyahMapping.delete_all
    NumberedAyah.delete_all
    AyahNumbering.delete_all
    Qiraat::Backfill::WordNumbers.new(csv_path: QiraatFixtures.upstream('word-index.csv'), dry_run: false, logger: nil).call
    Qiraat::Import::Numberings.new(counting_path: QiraatFixtures.upstream('counting.json'), catalog_path: QiraatFixtures.upstream('catalog.json'), systems: %w[kufi madani-last], surahs: [1, 2]).call
    Riwayah.find_by!(slug: 'warsh').update!(default_numbering: AyahNumbering.find_by!(slug: 'madani-last'))
  end

  after { FileUtils.rm_rf(base_path) }

  def sqlite_rows(db_file, sql)
    db = SQLite3::Database.new(db_file)
    db.results_as_hash = true
    db.execute(sql)
  ensure
    db&.close
  end

  describe 'the hand-made Hafs layout (mushaf 5)' do
    let(:resource_content) do
      ResourceContent.create!(name: 'KFGQPC HAFS wbw', slug: 'qpc-hafs-15-lines', sub_type: ResourceContent::SubType::Layout, resource_type: 'Mushaf',
                              resource_id: 5, cardinality_type: ResourceContent::CardinalityType::OnePage, approved: true)
    end
    let(:mushaf) { Mushaf.find(5) }
    let(:exporter) { described_class.new(resource_content: resource_content, base_path: base_path) }

    before do
      mushaf.update_columns(resource_content_id: resource_content.id, numbering_id: AyahNumbering.kufi.id, riwayah_id: Riwayah.find_by!(slug: 'hafs').id)
      Script.find_by!(slug: 'qpc-hafs').update_columns(font_file_url: 'https://static-cdn.tarteel.ai/qul/fonts/UthmanicHafs_V22.ttf')
    end

    it 'keeps the original info and pages columns first and adds the riwayah, numbering and face after them' do
      db = exporter.export_sqlite
      info = sqlite_rows(db, 'SELECT * FROM info').first
      expect(info.keys).to eq(%w[name number_of_pages lines_per_page font_name riwayah numbering font_family font_file source_package])
      expect(info.values_at('name', 'riwayah', 'numbering', 'font_family', 'font_file')).to eq(['KFGQPC HAFS', 'hafs', 'kufi', 'qpc-hafs', 'https://static-cdn.tarteel.ai/qul/fonts/UthmanicHafs_V22.ttf'])

      columns = sqlite_rows(db, 'PRAGMA table_info(pages)').map { |c| c['name'] }
      expect(columns).to eq(%w[page_number line_number line_type is_centered first_word_id last_word_id surah_number first_word_number last_word_number first_ayah last_ayah])
    end

    it 'writes the shared word numbers and the Kufi ayah keys of every line' do
      db = exporter.export_sqlite
      line = sqlite_rows(db, "SELECT * FROM pages WHERE page_number = 1 AND line_type = 'ayah' ORDER BY line_number").first
      first = Word.find_by!(location: '1:1:1')
      expect(line.values_at('first_word_id', 'first_word_number', 'first_ayah')).to eq([first.word_index, first.number, '1:1'])
      expect(line['last_word_number']).to be > first.number # the ayah-end marker carries no number: the line ends on its last word
      expect(line['last_ayah']).to match(/\A1:\d\z/)
    end

    it 'adds the same fields to info.json and to every ayah line of the page JSON' do
      dir = exporter.export_json
      info = JSON.parse(File.read("#{dir}/info.json"))
      expect(info.slice('riwayah', 'numbering', 'font_family', 'source_package')).to eq('riwayah' => 'hafs', 'numbering' => 'kufi', 'font_family' => 'qpc-hafs', 'source_package' => nil)
      page = JSON.parse(File.read("#{dir}/1.json"))
      ayah_lines = page['lines'].values.select { |l| l['type'] == 'ayah' }
      expect(ayah_lines).to all(include('first_word_id', 'last_word_id', 'data', 'first_word_number', 'last_word_number', 'first_ayah', 'last_ayah'))
      expect(ayah_lines.first['first_ayah']).to eq('1:1')
    end
  end

  describe 'a generated Warsh layout' do
    let(:mushaf) do
      Qiraat::Layout::Generator.new(key: 'warsh', path: QiraatFixtures.upstream('mushaf-warsh.json'), csv_path: QiraatFixtures.upstream('warsh-data.csv'), logger: nil, pages_count: 604).call
      Mushaf.find_by!(script: Script.find_by!(slug: 'qpc-warsh'), layout_source: Mushaf::GENERATED_LAYOUT_SOURCES)
    end
    let(:exporter) { described_class.new(resource_content: mushaf.resource_content, base_path: base_path) }

    it 'exports the ayah keys of the printed numbering and survives the end marker that has no word row' do
      expect(exporter.mushaf).to eq(mushaf)
      dir = exporter.export_json
      info = JSON.parse(File.read("#{dir}/info.json"))
      expect(info.values_at('riwayah', 'numbering', 'font_family')).to eq(%w[warsh madani-last qpc-warsh])
      page = JSON.parse(File.read("#{dir}/1.json"))
      line7 = page['lines']['7'] # Warsh 1:6 ends here with a marker that is no QUL word, then 1:7 begins
      expect(line7.values_at('first_ayah', 'last_ayah')).to eq(%w[1:6 1:7])
      expect(line7['first_word_number']).to eq(Word.find_by!(location: '1:7:3').number)
      expect(line7['data'].size).to eq(line7['last_word_id'] - line7['first_word_id'] + 1)
    end
  end
end
