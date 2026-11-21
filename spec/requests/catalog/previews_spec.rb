require 'clone_helper'

# The Preview tab of layouts, fonts and Quran scripts: the deferred `preview` prop that page
# navigation reloads on its own (Previews.for). Resources are the snapshot clone's published
# ones, found by name.
RSpec.describe 'Resource previews (the deferred preview prop)', type: :request do
  def resource(type, name)
    DownloadableResource.published.where(resource_type: type).where('name LIKE ?', "#{name}%").order(:id).first!
  end

  def page_path(resource, query = {})
    "/resources/#{resource.resource_type}/#{resource.to_param}#{"?#{query.to_query}" if query.any?}"
  end

  # The page, then the deferred preview as the browser asks for it.
  def preview(resource, query = {})
    get page_path(resource, query)
    expect(response).to have_http_status(:ok)
    expect(inertia).to have_deferred_props(:preview)
    inertia_load_deferred_props
    inertia.props[:preview]&.deep_symbolize_keys
  end

  def with_page_groups(groups)
    original = ENV.fetch('QUL_PAGE_GROUPS', nil)
    ENV['QUL_PAGE_GROUPS'] = groups.join(',')
    yield
  ensure
    ENV['QUL_PAGE_GROUPS'] = original
  end

  describe 'with the catalog page group on', page_groups: %w[catalog] do
    describe 'layouts' do
      let(:layout) { resource('mushaf-layout', 'KFGQPC V2 layout') }

      it 'renders the page a direct load names, and nothing but the preview on the reload' do
        expect(preview(layout, page: 300)).to include(kind: 'layout')
        expect(inertia.props[:preview][:page]).to include(number: 300, pagesCount: 604, fontCode: 'v2')
        expect(inertia.props[:preview][:page][:textFont][:family]).to eq('v2-p300')
        expect(inertia.props.keys.map(&:to_sym) - %i[errors head]).to eq([:preview])
      end

      it 'clamps a page beyond the page count, and reads a page that is not a number as page 1' do
        expect(preview(layout, page: 99_999).dig(:page, :number)).to eq(604)
        expect(preview(layout, page: 'abc').dig(:page, :number)).to eq(1)
        expect(preview(layout, page: -4).dig(:page, :number)).to eq(1)
      end

      it 'ignores a preview key given as a list or a hash' do
        expect(preview(layout, page: ['300']).dig(:page, :number)).to eq(1)
        script = resource('quran-script', 'QPC Hafs script - Ayah by Ayah')
        expect(preview(script, surah: { x: 2 }).dig(:surah, :number)).to eq(1)
      end

      it 'gives the explicit no-preview state, with the reason, for a layout without a font' do
        expect(preview(resource('mushaf-layout', 'Ligature Basd SVG Mushaf'))).to eq(
          kind: 'unavailable', reason: 'This layout is drawn with images, not a font, so it has no text preview yet.'
        )
      end
    end

    describe 'fonts' do
      it 'samples a font in the encoding its meta names, from the content database' do
        font = preview(resource('font', 'QPC Hafs font'))

        expect(font).to include(kind: 'font', view: 'sample', page: nil, ligatures: [])
        expect(font[:font]).to include(family: 'qpc-hafs', perPage: false)
        expect(font[:sample]).to eq(
          text: Verse.where(chapter_id: 1).order(:verse_number).pluck(:text_qpc_hafs).join(' '),
          source: 'Surah Al-Fatihah, text_qpc_hafs'
        )
      end

      it "shows a page font's mushaf page in that page's own file" do
        font = preview(resource('font', 'QPC V2 Font'), page: 3)

        expect(font[:sample]).to be_nil
        expect(font[:page]).to include(number: 3, pagesCount: 604)
        expect(font[:font][:family]).to eq('v2-p3')
        expect(font[:page][:textFont]).to eq(font[:font])
      end

      it 'lists the ligatures the old Ligatures tab lists, and reads the file the old Glyphs tab read' do
        font = resource('font', 'Surah name fonts v4')
        old_rows = old_glyph_url = nil
        with_page_groups([]) do
          get "/resources/font/#{font.id}/ligatures"
          old_rows = Nokogiri::HTML(response.body).css('[data-ligature-row] .ligature-preview')
                             .map { |cell| cell['data-ligature-text'] }
          get "/resources/font/#{font.id}/glyphs"
          old_glyph_url = Nokogiri::HTML(response.body).at_css('[data-font-preview-font-url-value]')
                                  &.[]('data-font-preview-font-url-value')
        end

        new = preview(font, view: 'ligatures')
        expect(new[:view]).to eq('ligatures')
        expect(old_rows.size).to eq(115)
        expect(new[:ligatures].pluck(:text)).to eq(old_rows)
        expect(new[:ligatures].pluck(:name)).to eq(JSON.parse(font.resource_content.meta_value('ligatures')).keys)
        expect(new[:font][:sources].find { |source| source[:format] == 'truetype' }[:url]).to eq(old_glyph_url)
      end

      it 'reads the same page file for the glyphs of a page font as the old Glyphs tab' do
        font = resource('font', 'QPC V1 Font')
        old_glyph_url = nil
        with_page_groups([]) do
          get "/resources/font/#{font.id}/glyphs"
          old_glyph_url = Nokogiri::HTML(response.body).at_css('[data-font-preview-font-url-value]')
                                  &.[]('data-font-preview-font-url-value')
        end

        new = preview(font, view: 'glyphs')
        expect(new[:view]).to eq('glyphs')
        expect(old_glyph_url).to end_with('quran_fonts/v1-optimized/ttf/p1.ttf')
        expect(new[:font][:sources].find { |source| source[:format] == 'truetype' }[:url]).to eq(old_glyph_url)
      end

      it 'redirects the old Ligatures and Glyphs tab URLs to those views' do
        font = resource('font', 'Surah name fonts v4')
        get "/resources/font/#{font.id}/ligatures"
        expect(response).to redirect_to("/resources/font/#{font.to_param}?view=ligatures")
        get "/resources/font/#{font.to_param}/glyphs"
        expect(response).to redirect_to("/resources/font/#{font.to_param}?view=glyphs")
      end

      it 'opens the sample for a font without ligatures that is asked for its ligatures' do
        expect(preview(resource('font', 'QPC Hafs font'), view: 'ligatures')[:view]).to eq('sample')
      end
    end

    describe 'Quran scripts' do
      it 'shows a word-level glyph script word by word, each word in the font of its page' do
        script = preview(resource('quran-script', 'QPC V2 Glyph - Word by Word'), surah: 112)

        expect(script).to include(kind: 'script', granularity: 'word', rendering: 'text', from: 1, to: 4,
                                  fontCode: 'v2')
        expect(script[:surah]).to include(number: 112, versesCount: 4)
        words = Word.where(verse_id: Verse.where(chapter_id: 112).select(:id)).reorder(:verse_id, :position)
        expect(script[:ayahs].flat_map { |ayah| ayah[:words].pluck(:text) }).to eq(words.pluck(:code_v2))
        expect(script[:ayahs].flat_map { |ayah| ayah[:words].pluck(:font) }.uniq).to eq(['v2-p604'])
        expect(script[:fonts].pluck(:family)).to eq(['v2-p604'])
      end

      it 'shows an ayah-level script ayah by ayah in its font' do
        script = preview(resource('quran-script', 'QPC Hafs script - Ayah by Ayah'), surah: 2, from: 255, to: 256)

        expect(script).to include(granularity: 'ayah', from: 255, to: 256)
        expect(script[:ayahs].map { |ayah| ayah.slice(:key, :text, :font) }).to eq(
          Verse.where(chapter_id: 2, verse_number: 255..256).order(:verse_number).map do |verse|
            { key: verse.verse_key, text: verse.text_qpc_hafs, font: 'qpc-hafs' }
          end
        )
      end

      it 'keeps only the rule tags of tajweed text' do
        script = preview(resource('quran-script', 'QPC Hafs Tajweed'), surah: 2, from: 255, to: 255)

        text = script[:ayahs].first[:text]
        expect(script[:rendering]).to eq('html')
        expect(text).to include('<rule class="madda_normal">')
        expect(Nokogiri::HTML.fragment(text).css('*').map(&:name).uniq).to eq(['rule'])
      end

      it 'shows the words of an image script as images, and the rows of a qiraat script' do
        images = preview(resource('quran-script', 'Black Images - Word by Word'), surah: 1, to: 1)
        expect(images).to include(rendering: 'image', fonts: [])
        expect(images[:ayahs].first[:words].first[:imageUrl]).to end_with('/qul/images/w/qa-black/1/1/1.png')

        warsh = resource('quran-script', 'Quran Script(Warsh) - Word by Word')
        qirat = preview(warsh, surah: 1, from: 2, to: 2)
        expect(qirat[:fonts].pluck(:family)).to eq(['qpc-warsh'])
        expect(qirat[:ayahs].first[:words].pluck(:text)).to eq(
          QuranScript::ByWord.where(resource_content_id: warsh.resource_content_id, chapter_id: 1, verse_number: 2)
                             .order(:word_number).pluck(:text)
        )
      end

      it 'clamps the surah and the range, ten ayahs by default and twenty at most' do
        script = resource('quran-script', 'QPC Hafs script - Ayah by Ayah')

        expect(preview(script, surah: 999).dig(:surah, :number)).to eq(114)
        expect(preview(script, surah: 2).slice(:from, :to)).to eq(from: 1, to: 10)
        expect(preview(script, surah: 2, from: 280, to: 900).slice(:from, :to)).to eq(from: 280, to: 286)
        expect(preview(script, surah: 2, from: 1, to: 900).slice(:from, :to)).to eq(from: 1, to: 20)
        expect(preview(script, surah: 2, from: 'x', to: 'y').slice(:from, :to)).to eq(from: 1, to: 1)
      end
    end

    it 'has a preview provider for every catalog type, and none for a type outside the catalog' do
      expect(Catalog::Taxonomy::TYPES.keys.reject { |type| Previews.provider(type) }).to eq([])
      expect(Previews.provider('qirat-recitation')).to be_nil
    end
  end

  describe 'with the catalog page group off', page_groups: [] do
    it 'leaves a layout page URL with a page number to the old page' do
      get "/resources/mushaf-layout/#{resource('mushaf-layout', 'KFGQPC V2 layout').id}?page=3"

      expect(response).to have_http_status(:ok)
      expect(controller).to be_a(ResourcesController)
    end
  end
end
