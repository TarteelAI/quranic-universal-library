# frozen_string_literal: true

require 'rails_helper'
require Rails.root.join('lib/qiraat/layout/generator').to_s
require Rails.root.join('lib/qiraat/layout/svg_diff').to_s

RSpec.describe Qiraat::Layout::SvgDiff do
  before do
    AyahMapping.delete_all
    NumberedAyah.delete_all
    AyahNumbering.delete_all
    Qiraat::Backfill::WordNumbers.new(csv_path: QiraatFixtures.upstream('word-index.csv'), dry_run: false, logger: nil).call
    Qiraat::Import::Numberings.new(counting_path: QiraatFixtures.upstream('counting.json'), catalog_path: QiraatFixtures.upstream('catalog.json'), systems: %w[kufi madani-last], surahs: [1, 2]).call
    Riwayah.find_by!(slug: 'warsh').update!(default_numbering: AyahNumbering.find_by!(slug: 'madani-last'))
    Qiraat::Layout::Generator.new(key: 'warsh', path: QiraatFixtures.upstream('mushaf-warsh.json'), csv_path: QiraatFixtures.upstream('warsh-data.csv'), logger: nil, pages_count: 604).call
  end

  let(:mushaf) { Mushaf.find_by!(layout_source: 'generated') }
  # page 1 only: the text slice holds 2:1-2:2 of page 2 while the polygons list 2:1-2:4
  let(:diff) { described_class.new(key: 'warsh', json_dir: QiraatFixtures.upstream('svg-warsh'), mushaf: mushaf, pages: [1], logger: nil) }

  it 'agrees with the quran-svg polygons on the opening page of the generated Warsh layout' do
    report = diff.call
    expect(report[:pages_checked]).to eq(1)
    expect(report[:pages_ok]).to eq(1)
    expect(report[:mismatches]).to be_empty
  end

  it 'reports an ayah whose words sit on the wrong line' do
    MushafWord.where(mushaf_id: mushaf.id, page_number: 1, line_number: 8).update_all(line_number: 7) # 1:7 runs over lines 7-8
    report = diff.call
    expect(report[:mismatches]).to include(a_hash_including(page: 1, kind: 'lines', ayah: '1:7', svg: [7, 8], generated: [7]))
  end

  it 'reads the lines of pages 3+ from the 15-line grid, several per band when the band is tall' do
    diff.send(:instance_variable_set, :@top0, 1.5)
    diff.send(:instance_variable_set, :@pitch, 35.87)
    expect(diff.send(:lines_of, [47.25, 86.7])).to eq([2])
    expect(diff.send(:lines_of, [2.0, 47.25])).to eq([1])
    expect(diff.send(:lines_of, [293.75, 327.5])).to eq([9])
    expect(diff.send(:lines_of, [115.0, 186.5])).to eq([4, 5]) # a band two lines tall
    expect(diff.send(:bands, 'M 8.0 2.0 L 339.0 2.0 L 339.0 47.25 L 8.0 47.25 Z M 249.0 47.25 L 339.0 47.25 L 339.0 86.7 L 249.0 86.7 Z')).to eq([[2.0, 47.25], [47.25, 86.7]])
    expect(diff.send(:bands, '213,38 66,38 66,70 213,70')).to eq([[38.0, 70.0]])
  end

  it 'ranks the opening-page lines among the page\'s own clustered boundaries, from the first text line' do
    # Hafs page 1 (quran-svg b4155f07): 1:1 is the basmalah on line 2; corners of one boundary jitter by up to 3 units
    polys = [
      { 'surahNumber' => 1, 'ayahNumber' => 1, 'polygon' => '181.08,18.31 57.54,18.31 57.54,48.94 181.08,48.94' },
      { 'surahNumber' => 1, 'ayahNumber' => 2, 'polygon' => '203.87,49.07 36.74,49.07 36.74,76.22 203.87,76.22' },
      { 'surahNumber' => 1, 'ayahNumber' => 5, 'polygon' => '229.77,103.24 56.04,103.24 56.04,130.26 229.52,131.26' },
      { 'surahNumber' => 1, 'ayahNumber' => 6, 'polygon' => '56.04,103.24 8.09,103.24 8.09,129.77 229.52,131.26 229.52,160.65 114.20,160.65 114.20,130.39' },
      { 'surahNumber' => 1, 'ayahNumber' => 7, 'polygon' => '113.70,130.39 13.82,130.39 13.82,162.77 37.11,162.77 37.11,189.05 73.48,189.05 73.48,214.95 229.52,214.95 229.52,160.28' }
    ]
    expect(diff.send(:cluster, [18.31, 48.94, 49.07, 129.77, 130.26, 131.26]).map(&:round)).to eq([18, 49, 130])
    expect(diff.send(:lines_for_opening_page, polys, 2)).to eq('1:1' => [2], '1:2' => [3], '1:5' => [5], '1:6' => [5, 6], '1:7' => [6, 7, 8])
    # Warsh page 1 starts on line 3 (header + basmalah lines) and its boundaries are exact
    warsh = JSON.parse(QiraatFixtures.upstream('svg-warsh/001.json').read)
    expect(diff.send(:lines_for_opening_page, warsh, 3)['1:7']).to eq([7, 8])
  end
end
