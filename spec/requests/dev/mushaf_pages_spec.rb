require 'clone_helper'

# The 001-04 spike page, on the snapshot clone's published layouts (ids as on the public site).
RSpec.describe 'Mushaf page spike (development only)', type: :request do
  def layout_id(name)
    DownloadableResource.published.where(resource_type: 'mushaf-layout').where('name LIKE ?', "#{name}%").sole.id
  end

  def line(number)
    inertia.props[:lines].find { |row| row[:number] == number }
  end

  it 'renders a glyph layout page from its word rows with that page font' do
    get "/__dev/mushaf_pages/#{layout_id('KFGQPC V2 layout')}", params: { page: 2 }

    expect(response).to have_http_status(:ok)
    expect(inertia).to render_component('dev/MushafPage')
    expect(inertia.props).to include(page: 2, pagesCount: 604, fontCode: 'v2')
    expect(inertia.props[:textFont]).to include(family: 'v2-p2', perPage: true)
    expect(inertia.props[:textFont][:sources].first[:url]).to end_with('/qul/fonts/quran_fonts/v2/woff2/p2.woff2')
    expect(line(1)).to include(surahNumber: 2, bismillah: false, words: [])
    expect(line(2)).to include(surahNumber: nil, bismillah: true, centered: true)
    expect(line(3)[:words]).not_to be_empty
    expect(inertia.props[:lines].sum { |row| row[:words].size }).to eq(
      MushafWord.where(mushaf_id: 1, page_number: 2).count
    )
  end

  it 'keeps a surah name and a bismillah that share one line' do
    get "/__dev/mushaf_pages/#{layout_id('Indopak 16 lines layout')}", params: { page: 187 }

    expect(line(3)).to include(surahNumber: 10, bismillah: true, centered: true)
  end

  it 'clamps the page to the layout page count' do
    get "/__dev/mushaf_pages/#{layout_id('Mushaf Qatar')}", params: { page: 610 }

    expect(inertia.props).to include(page: 604, pagesCount: 604)
    expect(inertia.props[:textFont]).to include(family: 'qpc-hafs', perPage: false)
  end

  it 'takes the mushaf from the layout meta, here the V4 Tajweed mushaf' do
    get "/__dev/mushaf_pages/#{layout_id('KFGQPC V4 layout')}", params: { page: 1 }

    expect(inertia.props).to include(fontCode: 'v4-tajweed')
    expect(inertia.props[:textFont][:sources].map { |source| source[:format] }).to eq(%w[woff2 woff truetype])
  end

  it 'shows a layout without a font or word rows as empty' do
    get "/__dev/mushaf_pages/#{layout_id('Ligature Basd SVG Mushaf')}"

    expect(response).to have_http_status(:ok)
    expect(inertia.props).to include(textFont: nil, lines: [])
  end

  it 'returns 404 for a resource that is not a published layout' do
    font_id = DownloadableResource.published.where(resource_type: 'font').pick(:id)
    get "/__dev/mushaf_pages/#{font_id}"

    expect(response).to have_http_status(:not_found)
  end
end
