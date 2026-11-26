# frozen_string_literal: true

require 'clone_helper'
require_relative '../../support/download_files'

# Card previews (Previews::Card): the kind each catalog and type page card carries, and the JSON
# a card fetches from /resources/:type/:slug/preview once it is on screen. Resources are the
# snapshot clone's published ones.
RSpec.describe 'Card previews (/resources/:type/:slug/preview)', type: :request do
  include Devise::Test::IntegrationHelpers
  include DownloadFiles

  def published(type)
    DownloadableResource.published.where(resource_type: type).order(:id).preload(:resource_content)
  end

  def named(type, name)
    published(type).where('name LIKE ?', "#{name}%").first!
  end

  def preview_path(resource, type: resource.resource_type, version: nil)
    "/resources/#{type}/#{resource.to_param}/preview#{"?v=#{version}" if version}"
  end

  def layout
    named('mushaf-layout', 'KFGQPC V2 layout')
  end

  def shared
    'max-age=3600, public, stale-while-revalidate=86400, s-maxage=86400'
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

    it 'is internal, and kept by the browser only without a version' do
      get preview_path(layout)

      expect(response.headers['X-Robots-Tag']).to eq('noindex')
      expect(response.headers['Cache-Control']).to eq('max-age=3600, private')
      expect(response.headers['Set-Cookie']).to be_nil
    end

    it 'gives each card the version of its preview URL, which changes with the resource and its content row' do
      get "/resources/#{layout.resource_type}"
      card = inertia.props[:resources].find { |resource| resource[:id] == layout.id }
      expect(card[:previewVersion]).to eq(Previews::Card.version(layout)).and match(/\A\h{12}\z/)

      get '/resources', params: { q: layout.name }
      expect(inertia.props[:results].find { |result| result[:id] == layout.id }[:previewVersion])
        .to eq(card[:previewVersion])
      get '/resources/surah-info'
      expect(inertia.props[:resources].pluck(:previewVersion).uniq).to eq([nil])

      resource = layout
      resource.updated_at += 1.minute
      edited = Previews::Card.version(resource)
      expect(edited).not_to eq(card[:previewVersion])
      resource.resource_content.updated_at += 1.minute
      expect(Previews::Card.version(resource)).not_to eq(edited)
    end

    # Forgery protection is off in test; on, inertia_rails would add its XSRF cookie to an XHR answer.
    it 'is shared with a version, the same for every visitor, and writes no cookie' do
      ActionController::Base.allow_forgery_protection = true
      path = preview_path(layout, version: Previews::Card.version(layout))
      get path
      anonymous = response.body
      expect(response.headers['Cache-Control']).to eq(shared)
      expect(response.headers['Set-Cookie']).to be_nil
      get path, headers: { 'If-None-Match' => response.headers['ETag'] }
      expect(response).to have_http_status(:not_modified)

      sign_in create_account(role: :admin)
      get path, headers: { 'Accept' => 'text/html', 'X-Requested-With' => 'XMLHttpRequest' }
      expect(response.body).to eq(anonymous)
      expect(response.headers['Cache-Control']).to eq(shared)
      expect(response.headers['Set-Cookie']).to be_nil
    ensure
      ActionController::Base.allow_forgery_protection = false
    end

    # A remembered visitor whose session has gone would be signed in again (and the sign-in
    # recorded) by anything that asks Warden for the user.
    it 'does not sign in a remembered visitor' do
      user = create_account
      post '/users/sign_in',
           params: { user: { email: user.email, password: DownloadFiles::PASSWORD, remember_me: '1' } }
      expect(cookies['remember_user_token']).to be_present
      cookies.delete('_quran_com-community_session')
      signed_in = user.reload.sign_in_count

      get preview_path(layout, version: 'x')

      expect(response).to have_http_status(:ok)
      expect(response.headers['Set-Cookie']).to be_nil
      expect(user.reload.sign_in_count).to eq(signed_in)
    end

    it 'keeps a restricted resource out of shared caches' do
      override_catalog(layout, 'copyright' => 'Spec restriction')

      get preview_path(layout, version: Previews::Card.version(layout))

      expect(response).to have_http_status(:ok)
      expect(response.headers['Cache-Control']).to eq('max-age=3600, private')
    end

    it 'is a 404 kept by no cache for an unpublished resource' do
      resource = layout
      resource.update_columns(published: false)

      get preview_path(resource, version: 'x')

      expect(response).to have_http_status(:not_found)
      expect(response.headers['Cache-Control']).not_to include('public')
    end

    # A preview that answers after the sign-in page would otherwise put back the session it was
    # sent with, and sign-in would lose its return path.
    it 'leaves the session cookie of a visitor who has one alone' do
      get '/users/sign_in', params: { user_return_to: '/resources/mushaf-layout' }
      expect(response.headers['Set-Cookie']).to include('_quran_com-community_session=')

      get preview_path(layout)

      expect(response).to have_http_status(:ok)
      expect(response.headers['Set-Cookie']).to be_nil
    end

    it 'is a 404 for a type without card previews, a layout without a font, a wrong type and an unknown slug' do
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
