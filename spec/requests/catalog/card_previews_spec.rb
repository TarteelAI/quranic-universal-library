# frozen_string_literal: true

require 'clone_helper'

# Card previews (Previews::Card): the kind each catalog and type page card carries, and the JSON
# a card fetches from /resources/:type/:slug/preview once it is on screen. Resources are the
# snapshot clone's published ones.
RSpec.describe 'Card previews (/resources/:type/:slug/preview)', type: :request do
  def published(type)
    DownloadableResource.published.where(resource_type: type).order(:id).preload(:resource_content)
  end

  def named(type, name)
    published(type).where('name LIKE ?', "#{name}%").first!
  end

  def preview_path(resource, type: resource.resource_type)
    "/resources/#{type}/#{resource.to_param}/preview"
  end

  def card_preview(resource)
    get preview_path(resource)
    expect(response).to have_http_status(:ok)
    expect(response.media_type).to eq('application/json')
    response.parsed_body.deep_symbolize_keys
  end

  describe 'with the catalog page group on', page_groups: ['catalog'] do
    it 'gives each catalog result and type page card its preview kind, and no preview data' do
      get '/resources', params: { sort: 'name', page: 1 }
      results = inertia.props[:results]
      expect(results.pluck(:previewKind)).to eq(
        results.map { |result| Previews::Card::KINDS[result[:type]] },
      )
      expect(results.flat_map(&:keys).uniq.map(&:to_sym)).not_to include(:preview)

      { 'mushaf-layout' => 'layout', 'recitation' => 'recitation', 'quran-script' => 'script',
        'translation' => 'text', 'tafsir' => 'text', 'transliteration' => 'text', 'font' => 'font',
        'surah-info' => nil, 'morphology' => nil, }.each do |type, kind|
        get "/resources/#{type}"
        expect(inertia.props[:resources].pluck(:previewKind).uniq).to eq([kind]), type
      end
    end

    it "gives a layout's first page with its fonts, without the page navigation" do
      preview = card_preview(named('mushaf-layout', 'KFGQPC V2 layout'))

      expect(preview[:kind]).to eq('layout')
      expect(preview[:page]).to include(number: 1, fontCode: 'v2')
      expect(preview[:page][:textFont][:family]).to eq('v2-p1')
      expect(preview[:page][:lines]).to be_present
      expect(preview[:page].keys).not_to include(:surahs, :pagesCount)
    end

    it "gives a surah recitation's Al-Fatihah file and nothing of its ayahs" do
      recitation = published('recitation').find do |resource|
        resource.resource_content.chapter? && Previews.for(resource, 'surah' => '1').respond_to?(:tracks)
      end
      preview = card_preview(recitation)

      expect(preview).to include(kind: 'recitation', granularity: 'surah',
                                 surah: { number: 1, name: 'Al-Fatihah', versesCount: 7 },)
      expect(preview[:tracks].size).to eq(1)
      expect(preview[:tracks]).to all(start_with('https://'))
      expect(preview.keys).not_to include(:ayahs, :surahs)
    end

    it 'gives an ayah-by-ayah recitation one Al-Fatihah file per ayah, in order' do
      preview = card_preview(published('recitation').find { |resource| resource.resource_content.one_ayah? })

      expect(preview).to include(kind: 'recitation', granularity: 'ayah')
      expect(preview[:tracks].size).to eq(7)
      expect(preview[:tracks]).to all(start_with('https://'))
    end

    it 'gives ayah 1:2 of a Quran script in its text and font' do
      preview = card_preview(named('quran-script', 'QPC Hafs script - Ayah by Ayah'))

      expect(preview).to include(kind: 'script', granularity: 'ayah', rendering: 'text')
      expect(preview[:ayah]).to include(key: '1:2', text: Verse.find_by!(verse_key: '1:2').text_qpc_hafs)
      expect(preview[:fonts].pluck(:family)).to eq(['qpc-hafs'])
    end

    it 'gives ayah 1:2 of a translation with its text, language and direction' do
      translation = published('translation').find do |resource|
        resource.resource_content&.language&.iso_code == 'en' && !resource.resource_content.one_word?
      end
      preview = card_preview(translation)

      expect(preview).to include(kind: 'text', granularity: 'ayah', locale: { code: 'en', direction: 'ltr' })
      expect(preview[:entry]).to include(key: '1:2', text: be_present)
      expect(preview[:entry][:ayahs]).to eq([{ key: '1:2', text: Verse.find_by!(verse_key: '1:2').text_uthmani }])
    end

    it "gives a tafsir's entry for ayah 1:2 cut to the card's length, without footnotes" do
      tafsir = published('tafsir').find do |resource|
        Previews.for(resource, Previews::Card::QUERY).entries.any? { |entry| entry.text.to_s.size > 1000 }
      end
      preview = card_preview(tafsir)

      expect(preview).to include(kind: 'text', granularity: 'ayah')
      expect(preview[:entry][:ayahs].pluck(:key)).to include('1:2')
      expect(preview[:entry]).to include(truncated: true, footnotes: [])
      expect(Nokogiri::HTML5.fragment(preview[:entry][:text]).text.size).to be <= Previews::Card::TEXT_LIMIT
    end

    it 'gives ayah 1:2 of a transliteration in Latin letters' do
      preview = card_preview(published('transliteration').find { |resource| !resource.resource_content.one_word? })

      expect(preview).to include(kind: 'text', granularity: 'ayah')
      expect(preview[:entry]).to include(key: '1:2', text: be_present)
    end

    it "gives the start of a font's sample in the font" do
      font = named('font', 'QPC Hafs')
      preview = card_preview(font)

      expect(preview).to include(kind: 'font', fontCode: nil)
      expect(preview[:font][:family]).to be_present
      expect(preview[:text].split.size).to be_between(1, Previews::CardFontResource::SAMPLE_WORDS)
    end

    it "gives a page font's first line of page 1 in the file of page 1" do
      preview = card_preview(named('font', 'QPC V2 Font'))

      expect(preview).to include(kind: 'font', fontCode: 'v2')
      expect(preview[:font]).to include(family: 'v2-p1', perPage: true)
      expect(preview[:text]).to be_present
    end

    it 'is internal and kept by the browser, not by shared caches' do
      get preview_path(named('mushaf-layout', 'KFGQPC V2 layout'))

      expect(response.headers['X-Robots-Tag']).to eq('noindex')
      expect(response.headers['Cache-Control']).to eq('max-age=3600, private')
      expect(response.headers['Set-Cookie']).to be_nil
    end

    # A preview that answers after the sign-in page would otherwise put back the session it was
    # sent with, and sign-in would lose its return path.
    it 'leaves the session cookie of a visitor who has one alone' do
      get '/users/sign_in', params: { user_return_to: '/resources/mushaf-layout' }
      expect(response.headers['Set-Cookie']).to include('_quran_com-community_session=')

      get preview_path(named('mushaf-layout', 'KFGQPC V2 layout'))

      expect(response).to have_http_status(:ok)
      expect(response.headers['Set-Cookie']).to be_nil
    end

    it 'is a 404 for a type without card previews, a layout without a font, a wrong type and an unknown slug' do
      layout = named('mushaf-layout', 'KFGQPC V2 layout')
      paths = [
        preview_path(published('surah-info').first),
        preview_path(named('mushaf-layout', 'Ligature Basd SVG Mushaf')),
        preview_path(layout, type: 'translation'),
        '/resources/translation/no-such-resource/preview',
      ]

      paths.each do |path|
        get path
        expect(response).to have_http_status(:not_found), path
        expect(response.body).to be_empty
      end
    end

    it 'answers for every published resource of the types with card previews, or says there is none' do
      counts = Hash.new(0)
      published(Previews::Card::KINDS.keys).each do |resource|
        preview = Previews::Card.for(resource)
        kind = Previews::Card.kind(resource.resource_type)
        expect(preview.nil? || preview['kind'] == kind).to be(true), "#{resource.id}: #{preview}"
        counts["#{resource.resource_type} #{preview ? 'preview' : 'none'}"] += 1
      end

      RSpec.configuration.reporter.message("Card previews: #{counts.sort.map do |key, count|
                                                               "#{key} #{count}"
                                                             end.join(', ')}")
      expect(counts.keys.grep(/preview\z/).map { |key| key.split.first }).to match_array(Previews::Card::KINDS.keys)
    end
  end

  describe 'with the catalog page group off', page_groups: [] do
    it 'has no card preview URL' do
      get preview_path(named('mushaf-layout', 'KFGQPC V2 layout'))

      expect(response).to have_http_status(:not_found)
    end
  end
end
