require 'clone_helper'
require 'net/http'

# The Preview tab of recitations, translations, tafsirs and transliterations, and the record
# samples of the other types (Previews::Recitation, Previews::Text, Previews::Records), as the
# deferred `preview` prop the page loads after the first response.
RSpec.describe 'Audio, text and record previews', type: :request, page_groups: %w[catalog] do
  def published(type)
    DownloadableResource.published.where(resource_type: type).order(:id).preload(:resource_content)
  end

  def page_path(resource, query = {})
    "/resources/#{resource.resource_type}/#{resource.to_param}#{"?#{query.to_query}" if query.any?}"
  end

  def preview(resource, query = {})
    get page_path(resource, query)
    expect(response).to have_http_status(:ok)
    inertia_load_deferred_props
    inertia.props[:preview]&.deep_symbolize_keys
  end

  # The page as the browser has it once the deferred preview arrived, rendered by the SSR bundle.
  def server_rendered_preview(resource)
    get page_path(resource)
    page = JSON.parse(Nokogiri::HTML(response.body).at('script[data-page="app"]').text)
    inertia_load_deferred_props
    page['props']['preview'] = inertia.props[:preview]
    SsrServer.with_ssr do
      uri = URI("http://localhost:#{SsrServer::PORT}/render")
      JSON.parse(Net::HTTP.post(uri, page.to_json, 'Content-Type' => 'application/json').body).fetch('body')
    end
  end

  describe 'recitations' do
    let(:recitations) { published('recitation').to_a }

    it 'gives a surah recitation one track and, where it has segments, the times of each ayah' do
      recitation = recitations.find do |r|
        audio = Audio::Recitation.find_by(resource_content_id: r.resource_content_id)
        r.resource_content.chapter? && audio && Audio::Segment.exists?(audio_recitation_id: audio.id, chapter_id: 114)
      end
      preview = preview(recitation, surah: 114)

      expect(preview).to include(kind: 'recitation', granularity: 'surah', highlights: true)
      expect(preview[:tracks].size).to eq(1)
      expect(preview[:ayahs].map { |ayah| ayah[:key] }).to eq((1..6).map { |n| "114:#{n}" })
      expect(preview[:ayahs]).to all(include(track: 0, from: Integer, to: Integer))
      expect(preview[:ayahs].each_cons(2)).to all(satisfy { |a, b| a[:to] <= b[:from] })
      expect(inertia.props.keys.map(&:to_sym) - %i[errors head]).to eq([:preview])
    end

    it 'gives a surah recitation without segments no times, and says so with highlights false' do
      recitation = recitations.find do |r|
        next false unless r.resource_content.chapter?

        audio = Audio::Recitation.find_by(resource_content_id: r.resource_content_id)
        audio && !Audio::Segment.exists?(audio_recitation_id: audio.id, chapter_id: 1) &&
          Audio::ChapterAudioFile.exists?(audio_recitation_id: audio.id, chapter_id: 1)
      end
      preview = preview(recitation)

      expect(preview).to include(kind: 'recitation', granularity: 'surah', highlights: false)
      expect(preview[:ayahs]).to all(include(from: nil, to: nil))
    end

    it 'gives an ayah-by-ayah recitation one track per ayah' do
      preview = preview(recitations.find { |r| r.resource_content.one_ayah? }, surah: 112)

      expect(preview).to include(granularity: 'ayah', highlights: true)
      expect(preview[:tracks].size).to eq(4)
      expect(preview[:ayahs].map { |ayah| ayah[:track] }).to eq([0, 1, 2, 3])
      expect(preview[:tracks]).to all(start_with('https://'))
    end
  end

  describe 'text direction and language' do
    def translation(direction)
      published('translation').find do |r|
        r.resource_content.language&.direction == direction && !r.resource_content.one_word?
      end
    end

    it 'renders a right-to-left translation with dir="rtl" and its language code, on the server' do
      resource = translation('rtl')
      code = resource.resource_content.language.iso_code
      html = Nokogiri::HTML(server_rendered_preview(resource))

      text = html.css('[data-testid="text-preview"] [data-entry] div[lang]')
      expect(text).not_to be_empty
      expect(text.map { |node| [node['lang'], node['dir']] }.uniq).to eq([[code, 'rtl']])
    end

    it 'renders a left-to-right translation with dir="ltr", on the server' do
      resource = translation('ltr')
      code = resource.resource_content.language.iso_code
      html = Nokogiri::HTML(server_rendered_preview(resource))

      text = html.css('[data-testid="text-preview"] [data-entry] div[lang]')
      expect(text).not_to be_empty
      expect(text.map { |node| [node['lang'], node['dir']] }.uniq).to eq([[code, 'ltr']])
    end
  end

  describe 'sanitizing' do
    let(:attack) { '<script>alert(1)</script><b onclick="steal()">kept</b><a href="javascript:x">link</a>' }

    it 'strips scripts, handlers and links from translation text and footnotes' do
      resource = published('translation').find { |r| r.resource_content.one_ayah? }
      row = Translation.find_by!(resource_content_id: resource.resource_content_id, verse_key: '1:1')
      row.update_columns(text: "#{attack}<sup foot_note=1>1</sup>")
      FootNote.create!(translation_id: row.id, text: attack, resource_content_id: row.resource_content_id,
                       language_id: row.language_id)

      entry = preview(resource)[:entries].first
      expect(entry[:text]).to eq('alert(1)<b>kept</b>link<sup>1</sup>')
      expect(entry[:footnotes].last[:text]).to eq('alert(1)<b>kept</b>link')
    end

    it 'strips them from tafsir text' do
      resource = published('tafsir').first
      Tafsir.where(resource_content_id: resource.resource_content_id, archived: false)
            .where('start_verse_id <= 1 AND end_verse_id >= 1').update_all(text: "<p>#{attack}</p>")

      expect(preview(resource)[:entries].first[:text]).to eq('<p>alert(1)<b>kept</b>link</p>')
    end

    it 'cuts a very long tafsir entry to its start and says so' do
      resource = published('tafsir').first
      long = Array.new(400) { |n| "<p>#{"Paragraph #{n}. " * 10}</p>" }.join
      Tafsir.where(resource_content_id: resource.resource_content_id, archived: false)
            .where('start_verse_id <= 1 AND end_verse_id >= 1').update_all(text: long)

      entry = preview(resource)[:entries].first
      expect(entry[:truncated]).to be(true)
      expect(entry[:text].size).to be <= Previews::TEXT_LIMIT
      expect(entry[:text]).to start_with('<p>Paragraph 0. ').and end_with('</p>')
    end
  end

  describe 'tafsir ranges' do
    it 'shows the entries covering the range and continues after the last group' do
      resource = published('tafsir').find do |r|
        Tafsir.exists?(['resource_content_id = ? AND chapter_id = 2 AND group_verses_count > 1', r.resource_content_id])
      end
      group = Tafsir.where(resource_content_id: resource.resource_content_id, chapter_id: 2, archived: false)
                    .where('group_verses_count > 1').order(:start_verse_id).first
      first = Verse.find(group.start_verse_id)
      preview = preview(resource, surah: 2, from: first.verse_number)

      expect(preview[:from]).to eq(first.verse_number)
      expect(preview[:entries].first[:ayahs].size).to eq(group.end_verse_id - group.start_verse_id + 1)
      expect(preview[:to]).to be >= Verse.find(group.end_verse_id).verse_number
    end
  end

  describe 'record samples' do
    def records(type, query = {})
      published(type).to_h { |resource| [resource, preview(resource, query)] }
    end

    def expect_bounded(previews)
      previews.each do |resource, preview|
        expect(preview[:kind]).to eq('records'), "#{resource.name}: #{preview}"
        expect(preview[:limit]).to eq(Previews::Records::LIMIT)
        expect(preview[:records].size).to be <= Previews::Records::LIMIT
      end
    end

    it 'surah info: the resource own record for the chosen surah' do
      previews = records('surah-info', surah: 2)
      expect_bounded(previews)
      previews.each do |resource, preview|
        ids = ChapterInfo.where(resource_content_id: resource.resource_content_id, chapter_id: 2).pluck(:id)
        expect(preview[:records].map { |record| record[:key] }).to eq(ids.map(&:to_s))
        expect(preview[:surah]).to include(number: 2)
      end
    end

    it 'ayah themes: the themes of the surah, at most the bound' do
      previews = records('ayah-theme', surah: 2)
      expect_bounded(previews)
      expect(AyahTheme.where(chapter_id: 2).count).to be > Previews::Records::LIMIT
      expect(previews.values.first[:records].size).to eq(Previews::Records::LIMIT)
      expect(previews.values.first[:records].first[:label]).to eq('2:1–2:5').or start_with('2:1')
    end

    it 'ayah topics: the first topics, with the ayahs each covers' do
      previews = records('ayah-topics')
      expect_bounded(previews)
      preview = previews.values.first
      expect(preview[:surah]).to be_nil
      expect(preview[:records].size).to eq(Previews::Records::LIMIT)
      expect(preview[:records].first).to include(label: Topic.order(:id).first.name)
    end

    it 'similar ayahs and mutashabihat: matches of the chosen surah' do
      previews = records('similar-ayah', surah: 2).merge(records('mutashabihat', surah: 2))
      expect_bounded(previews)
      previews.each_value do |preview|
        expect(preview[:records].size).to eq(Previews::Records::LIMIT)
        expect(preview[:records]).to all(include(label: /\A2:\d+/))
      end
    end

    it 'morphology: the words or ayahs of the chosen surah with their lemma, stem or root' do
      previews = records('morphology', surah: 112)
      expect_bounded(previews)
      previews.each do |resource, preview|
        labels = preview[:records].map { |record| record[:label] }
        expect(labels).to all(match(resource.resource_content.one_word? ? /\A112:\d+:\d+\z/ : /\A112:\d+\z/))
        expect(preview[:records].pluck(:arabic, :tags).flatten.compact).not_to be_empty
      end
    end

    it 'Quran metadata: the first records of each kind' do
      previews = records('quran-metadata')
      expect_bounded(previews)
      labels = previews.to_h do |resource, preview|
        [resource.resource_content.cardinality_type, preview[:records].first[:label]]
      end
      expect(labels).to include('1_juz' => 'Juz 1', '1_hizb' => 'Hizb 1', '1_chapter' => '1. Al-Fatihah',
                                '1_ayah' => '1:1', '1_sajda' => 'Sajdah 1')
      expect(previews.values.map { |preview| preview[:records].size }).to all(be_between(1, Previews::Records::LIMIT))
    end

    it 'gives the explicit no-preview state when the records cannot be told' do
      resource = published('morphology').first
      resource.resource_content.update_columns(meta_data: { 'morphology-resource-type' => 'unknown' })

      expect(preview(resource)).to eq(kind: 'unavailable',
                                      reason: 'There is no sample of this morphology resource yet.')
    end
  end
end
