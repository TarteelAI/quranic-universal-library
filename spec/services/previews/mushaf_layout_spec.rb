require 'clone_helper'

# The layout preview provider on its own: no controller, request or Inertia, as the public API
# would call it. Layouts are the snapshot clone's published ones (ids as on the public site).
RSpec.describe Previews::MushafLayout do
  def layout(name)
    DownloadableResource.published.where(resource_type: 'mushaf-layout').where('name LIKE ?', "#{name}%")
                        .preload(:resource_content).sole
  end

  def preview(name, page)
    Previews.for(layout(name), { 'page' => page })
  end

  def line(page, number)
    page.lines.find { |row| row.number == number }
  end

  # The SQL a block runs, without schema and transaction statements.
  def queries
    statements = []
    callback = lambda do |*, payload|
      statements << payload[:sql] unless %w[SCHEMA TRANSACTION].include?(payload[:name]) || payload[:cached]
    end
    ActiveSupport::Notifications.subscribed(callback, 'sql.active_record') { yield }
    statements
  end

  it 'draws a glyph layout page from its word rows with that page font' do
    page = preview('KFGQPC V2 layout', '2').page

    expect(page).to have_attributes(number: 2, pages_count: 604, font_code: 'v2')
    expect(page.text_font).to have_attributes(family: 'v2-p2', per_page: true)
    expect(page.text_font.sources.first.url).to end_with('/qul/fonts/quran_fonts/v2/woff2/p2.woff2')
    expect(line(page, 1)).to have_attributes(surah_number: 2, bismillah: false, words: [])
    expect(line(page, 2)).to have_attributes(surah_number: nil, bismillah: true, centered: true)
    expect(page.lines.sum { |row| row.words.size }).to eq(MushafWord.where(mushaf_id: 1, page_number: 2).count)
    expect(page.surahs.size).to eq(114)
    expect(page.surahs.first(2).map(&:page)).to eq([1, 2])
  end

  it 'keeps a surah name and a bismillah that share one line' do
    expect(line(preview('Indopak 16 lines layout', '187').page, 3)).to have_attributes(
      surah_number: 10, bismillah: true, centered: true
    )
  end

  it 'clamps the page to the page count, and reads anything else as page 1' do
    expect(preview('Mushaf Qatar', '610').page).to have_attributes(number: 604, pages_count: 604)
    expect(preview('Mushaf Qatar', '610').page.text_font).to have_attributes(family: 'qpc-hafs', per_page: false)
    expect(preview('Mushaf Qatar', 'abc').page.number).to eq(1)
    expect(preview('Mushaf Qatar', '-3').page.number).to eq(1)
    expect(Previews.for(layout('Mushaf Qatar')).page.number).to eq(1)
  end

  it 'takes the mushaf from the layout meta, here the V4 Tajweed mushaf' do
    page = preview('KFGQPC V4 layout', '1').page

    expect(page.font_code).to eq('v4-tajweed')
    expect(page.text_font.sources.map(&:format)).to eq(%w[woff2 woff truetype])
  end

  it 'says why a layout without a font has no preview' do
    expect(preview('Ligature Basd SVG Mushaf', '1')).to eq(
      Previews::Unavailable.new(reason: 'This layout is drawn with images, not a font, so it has no text preview yet.')
    )
  end

  it 'serializes to the props the page reads' do
    json = Previews.as_json(preview('KFGQPC V2 layout', '2'))

    expect(json.keys).to eq(%w[kind page])
    expect(json['kind']).to eq('layout')
    expect(json['page'].keys).to eq(%w[number pagesCount fontCode textFont surahNameFont surahHeaderFont
                                       bismillahFont lines surahs])
  end

  it 'runs the same few queries for any page of any layout' do
    counts = [['KFGQPC V2 layout', '2'], ['KFGQPC V2 layout', '300'], ['Indopak 9 lines', '1890'],
              ['Mushaf Qatar', '50']].map do |name, page|
      resource = layout(name)
      queries { Previews.as_json(Previews.for(resource, { 'page' => page })) }.size
    end

    puts "\n    Queries per layout page: #{counts.join(', ')}"
    expect(counts.uniq.size).to eq(1)
    expect(counts.first).to be <= 8
  end
end
