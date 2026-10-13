# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Mushaf, 'numbering and sources (P5.1)' do
  let(:mushaf) { Mushaf.find(5) }

  before do
    AyahNumbering.delete_all
    NumberedAyah.delete_all
    @kufi = AyahNumbering.create!(slug: 'kufi', kind: 'madhhab', counting_system: CountingSystem.kufi, total_ayahs: 6236)
    @madani = AyahNumbering.create!(slug: 'madani-last', kind: 'madhhab', counting_system: CountingSystem.find_by!(slug: 'madani-last'), total_ayahs: 6214)
    @susi_printed = AyahNumbering.create!(slug: 'kfgqpc-susi-v3.0', kind: 'printed', counting_system: CountingSystem.find_by!(slug: 'madani-first'), total_ayahs: 6218, meta_data: { 'edition' => 'susi' })
    Riwayah.find_by!(slug: 'susi').update!(default_numbering: @susi_printed)
  end

  it 'accepts the attributed madhhab numbering and rejects another' do
    mushaf.numbering = @kufi
    expect(mushaf).to be_valid
    mushaf.numbering = @madani
    expect(mushaf).not_to be_valid
    expect(mushaf.errors[:numbering].first).to include('madani-last is not a numbering of hafs')
  end

  it 'accepts a printed numbering only for its own riwayah' do
    susi = Mushaf.new(name: 'susi', riwayah: Riwayah.find_by!(slug: 'susi'), pages_count: 604, lines_per_page: 15, numbering: @susi_printed)
    expect(susi).to be_valid
    mushaf.numbering = @susi_printed
    expect(mushaf).not_to be_valid
  end

  it 'reads pdf_url from the column, falling back to the legacy table' do
    expect(mushaf.pdf_url).to eq('https://download.qurancomplex.gov.sa/resources_dev/UthmanicHafs_v18.zip') # the column, seeded by the P5.1 backfill (P7.5 dropped the model constant)
    mushaf.update_columns(pdf_url: 'https://example.test/x.pdf')
    expect(mushaf.reload.pdf_url).to eq('https://example.test/x.pdf')
    expect(Mushaf.new(id: 999).pdf_url).to be_nil
  end

  it 'takes its font class from default_font_name, else from the script (P5.4)' do
    expect(mushaf.font_code).to eq('qpc-hafs')
    mushaf.default_font_name = nil
    expect(mushaf.font_code).to eq(mushaf.script.font_css_class)
    expect(Mushaf.new.font_code).to be_nil
  end

  it 'defaults layout_source to manual and validates it' do
    expect(mushaf.layout_source).to eq('manual')
    mushaf.layout_source = 'guessed'
    expect(mushaf).not_to be_valid
    mushaf.layout_source = 'generated'
    mushaf.numbering = @kufi
    expect(mushaf).to be_valid
  end
end
