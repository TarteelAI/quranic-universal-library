# frozen_string_literal: true

require 'rails_helper'
require Rails.root.join('lib/qiraat/layout/generator').to_s

# The fixture slice carries the first two pages of the Warsh and Hafs mushaf
# files (al-Fatihah and the opening of al-Baqarah) with the Complex CSV rows
# for those pages. The words table holds 1:1-1:7 and 2:1-2:3, so printed
# words past 2:3 are unmapped and skipped; the expectations stay within the
# mapped ayahs.
RSpec.describe Qiraat::Layout::Generator do
  let(:counting) { QiraatFixtures.upstream('counting.json') }
  let(:catalog) { QiraatFixtures.upstream('catalog.json') }

  before do
    AyahMapping.delete_all
    NumberedAyah.delete_all
    AyahNumbering.delete_all
    Qiraat::Backfill::WordNumbers.new(csv_path: QiraatFixtures.upstream('word-index.csv'), dry_run: false, logger: nil).call
    Qiraat::Import::Numberings.new(counting_path: counting, catalog_path: catalog, systems: %w[kufi madani-last], surahs: [1, 2]).call
    Riwayah.find_by!(slug: 'warsh').update!(default_numbering: AyahNumbering.find_by!(slug: 'madani-last'))
    Riwayah.find_by!(slug: 'hafs').update!(default_numbering: AyahNumbering.kufi)
  end

  def generate(key, **opts)
    described_class.new(
      key: key,
      path: QiraatFixtures.upstream("mushaf-#{key}.json"),
      csv_path: QiraatFixtures.upstream("#{key}-data.csv"),
      logger: nil, pages_count: 604, **opts
    )
  end

  describe 'warsh' do
    let!(:report) { generate('warsh').call }
    let(:mushaf) { Mushaf.find_by!(script: Script.find_by!(slug: 'qpc-warsh'), layout_source: 'generated') }
    let(:rows) { MushafWord.where(mushaf_id: mushaf.id).order(:page_number, :position_in_page) }

    it 'creates a disabled mushaf on the riwayah, its script and its printed numbering' do
      expect(mushaf.riwayah.slug).to eq('warsh')
      expect(mushaf.numbering.slug).to eq('madani-last')
      expect(mushaf.enabled).to be(false)
      expect(mushaf.default_font_name).to eq('qpc-warsh')
      expect(mushaf.lines_per_page).to eq(15)
      expect(mushaf.resource_content.sub_type).to eq('layout')
      expect(mushaf.pdf_url).to include('warsh')
    end

    it 'lays out page 1 as the print does: header, the uncounted basmalah, then seven ayahs ending on line 8' do
      aligns = MushafLineAlignment.where(mushaf_id: mushaf.id, page_number: 1).order(:line_number)
      expect(aligns.first.alignment).to eq('surah_name')
      expect(aligns.first.meta_data['surah-number']).to eq(1)
      expect(aligns.where(alignment: 'bismillah')).to be_empty
      expect(aligns.where(alignment: 'center').pluck(:line_number)).to eq((2..8).to_a)

      basmalah = rows.where(page_number: 1, line_number: 2)
      expect(basmalah.pluck(:word_id)).to eq([1, 2, 3, 4])
      expect(basmalah.map { |r| r.ayah.ayah_key }.uniq).to eq(['1:0'])
      expect(basmalah.where(char_type_name: 'end')).to be_empty

      first = rows.where(page_number: 1, line_number: 3)
      expect(first.where(char_type_name: 'end').first.text).to eq('١')
      expect(first.where(char_type_name: 'end').first.ayah.ayah_key).to eq('1:1')
      expect(first.where(char_type_name: 'end').first.word_id).to eq(Word.unscoped.find_by!(verse_id: Verse.find_by!(verse_key: '1:2').id, char_type_id: CharType.find_by!(name: 'end').id).id) # the Kufi end marker of 1:2
      expect(rows.where(page_number: 1).maximum(:line_number)).to eq(8)
      expect(rows.where(page_number: 1, char_type_name: 'end').count).to eq(7)
    end

    it 'merges Kufi 2:1 and 2:2 into one printed ayah with a single marker' do
      page2 = rows.where(page_number: 2)
      expect(MushafLineAlignment.where(mushaf_id: mushaf.id, page_number: 2).order(:line_number).limit(2).pluck(:alignment)).to eq(%w[surah_name bismillah])
      alm = page2.find_by!(word_id: Word.find_by!(location: '2:1:1').id)
      expect(alm.line_number).to eq(3)
      expect(alm.ayah.ayah_key).to eq('2:1')
      expect(page2.where(verse_id: Verse.find_by!(verse_key: '2:1').id, char_type_name: 'end')).to be_empty
      marker = page2.where(verse_id: Verse.find_by!(verse_key: '2:2').id, char_type_name: 'end').first
      expect(marker.text).to eq('١')
      expect(marker.word_id).to eq(Word.unscoped.find_by!(verse_id: Verse.find_by!(verse_key: '2:2').id, char_type_id: CharType.find_by!(name: 'end').id).id)
      expect(marker.ayah.ayah_key).to eq('2:1')
    end

    it 'agrees with the Complex CSV on every mapped ayah and records the page stats' do
      disagreeing = report[:csv][:disagreements].map { |d| d[:ayah] }
      expect(disagreeing & %w[1:1 1:2 1:3 1:4 1:5 1:6 1:7 2:1 2:2]).to be_empty
      expect(report[:unmapped_positions]).not_to be_empty # words past 2:3 are not in the slice
      page = MushafPage.find_by!(mushaf_id: mushaf.id, page_number: 1)
      expect(page.first_ayah.ayah_key).to eq('1:0')
      expect(page.last_ayah.ayah_key).to eq('1:7')
      expect(page.lines_count).to eq(8)
      expect(page.verse_mapping.values.first).to include('range' => '1-7', 'count' => 7)
    end

    it 'rebuilds the same mushaf on a second run' do
      before_id = mushaf.id
      generate('warsh').call
      expect(Mushaf.where(layout_source: 'generated').count).to eq(1)
      expect(Mushaf.find(before_id).mushaf_words.count).to eq(rows.count)
    end
  end

  describe 'hafs dry run' do
    it 'matches mushaf 5 page for page and the CSV line for line without writing anything' do
      report = generate('hafs', dry_run: true, compare_mushaf_id: 5).call
      expect(report[:compare][:page_mismatches]).to eq(0)
      expect(report[:csv][:disagreements].map { |d| d[:ayah] } & %w[1:1 1:2 1:3 1:4 1:5 1:6 1:7 2:1 2:2 2:3]).to be_empty
      expect(report[:stats][:markers_without_word]).to eq(0)
      expect(Mushaf.where(layout_source: 'generated')).to be_empty
    end
  end

  describe 'hafs' do
    # qpc-hafs-15-lines is the slug of mushaf 5's own layout resource (and of another hand-made one: slugs are not unique)
    let!(:hand_made) do
      ResourceContent.create!(name: 'KFGQPC HAFS wbw', slug: 'qpc-hafs-15-lines', sub_type: ResourceContent::SubType::Layout, resource_type: 'Mushaf',
                              resource_id: 5, cardinality_type: ResourceContent::CardinalityType::OnePage, approved: true).tap { |rc| Mushaf.find(5).update_columns(resource_content_id: rc.id) }
    end

    it 'leaves the hand-made layout resource alone and gives the generated mushaf one of its own' do
      generate('hafs').call
      generated = Mushaf.find_by!(script: Script.find_by!(slug: 'qpc-hafs'), layout_source: 'generated')
      expect(hand_made.reload.attributes.slice('name', 'approved', 'resource_id')).to eq('name' => 'KFGQPC HAFS wbw', 'approved' => true, 'resource_id' => '5') # resource_id is a string column
      expect(Mushaf.find(5).resource_content_id).to eq(hand_made.id)
      expect(generated.resource_content.slug).to eq('qpc-hafs-15-lines-generated')
      expect(generated.resource_content.resource_id.to_i).to eq(generated.id)
    end

    it 'rebuilds a mushaf already marked svg-verified in place instead of adding a second one' do
      generate('hafs').call
      generated = Mushaf.find_by!(script: Script.find_by!(slug: 'qpc-hafs'), layout_source: 'generated')
      generated.update_columns(layout_source: 'svg-verified')
      generate('hafs').call
      expect(Mushaf.where(script: generated.script, layout_source: Mushaf::GENERATED_LAYOUT_SOURCES).pluck(:id)).to eq([generated.id])
      expect(generated.reload.layout_source).to eq('generated')
    end
  end
end
