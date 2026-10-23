class ResourcePresenter < ApplicationPresenter
  require "cgi"
  include ResourcesHelper

  def meta_title
    if index?
      'QUL Resources — Download Quran Data: Translations, Tafsir, Audio, Scripts & JSON Datasets'
    elsif show?
      @resource.group_info
    elsif action_name == 'related_resources'
    elsif action_name == 'detail'
      @resource.humanize
    end
  end

  def meta_description
    if show?
      resource_key = resource.resource_type.tr('-', '_').to_sym
      card = downloadable_resource_cards[resource_key]
      if card
        card.description
      end
    elsif action_name == 'detail'
      generate_resource_description
    else
      'Download a curated collection of Quran data as JSON — recitations, translations, tafsir, word-by-word, Uthmani/IndoPak scripts, metadata and themes — for developers, researchers and students.'
    end
  end

  def meta_keywords
    global_keywords = ['Quran data', 'Quran json data', 'download Quran data']

    if index?
      (['Quran resources', 'Quran translations json', 'Quran tafsir json', 'Quran datasets', 'Quran audio recitations', 'Uthmani script json'] + global_keywords).join(', ')
    elsif show? || action_name == 'detail'
      ([resource.name, "#{resource.name} json data", resource.resource_type, "download #{resource.resource_type.humanize}", resource.humanize_cardinality_type, resource.tags] + global_keywords).compact_blank.join(', ')
    end
  end

  def generate_resource_description
    verse = load_ayah
    resource_type = resource.resource_type.tr('-', '_').to_sym

    case resource_type
    when :recitation
      "Download Quran audio recitation by #{resource.name} — MP3 files and word-by-word segment data as JSON for every ayah."
    when :quran_script
      "Download #{resource.name} Quran script as JSON — Uthmani/IndoPak verse and word text data for every ayah."
    when :font
      "Download #{resource.name} — Quran fonts for Arabic and Quranic text, with glyph code-point data."
    when :quran_metadata
      "Download #{resource.name} — Quran metadata as JSON data (surah, ayah, juz, page and more)."
    when :surah_info
      if info = ChapterInfo.where(resource_content_id: resource.resource_content_id, chapter_id: verse.chapter_id).first
        clean_meta_description(info.text)
      else
        "#{resource.name} - Download Quran Surah Information"
      end
    when :ayah_topics
      "Download #{resource.name} — Quran ayah topics and thematic index as JSON data."
    when :morphology
      # TODO: Find the morphology data for the specific verse
      "Download #{resource.name} — Quran morphological data as JSON."
    when :mutashabihat
      "Download #{resource.name} — Quran mutashabihat (similar ayah) data as JSON."
    when :similar_ayah
      "Download #{resource.name} — Quran similar ayah data as JSON."
    when :ayah_theme
      theme = AyahTheme.for_verse(load_ayah)
      if theme
        clean_meta_description("#{resource.name}(#{verse.verse_key}) - #{theme.theme}")
      else
        "#{resource.name} - Download Quran Ayah Theme Data"
      end
    else
      ""
    end
  end

  DetailTab = Struct.new(:key, :label, :partial, :lazy, keyword_init: true)

  # Tabs under the resource details: Preview, Docs, Licence, then any tabs
  # specific to the resource type. Preview lives at the resource URL, the
  # others at /resources/:type/:id/:tab so they can be linked to.
  def detail_tabs(downloadable = resource)
    tabs = [DetailTab.new(key: 'preview', label: 'Preview', partial: 'resources/preview_tab')]
    if (docs = docs_partial(downloadable))
      tabs << DetailTab.new(key: 'docs', label: 'Docs', partial: docs, lazy: true)
    end
    tabs << DetailTab.new(key: 'licence', label: 'Licence', partial: 'resources/licence', lazy: true)
    tabs + extra_detail_tabs(downloadable)
  end

  def detail_tab
    params[:tab].presence || 'preview'
  end

  def find_detail_tab(key = detail_tab)
    detail_tabs.detect { |tab| tab.key == key }
  end

  def docs_partial(downloadable = resource)
    partial = "resources/docs/#{preview_partial(downloadable)}"
    partial if context.lookup_context.exists?(partial, [], true)
  end

  # Stimulus controller and values the tab section needs for this resource,
  # e.g. the font preview, which drives the Preview, Ligatures and Glyphs tabs.
  def detail_tabs_data(downloadable = resource)
    return { controller: 'resource-tabs' } unless preview_partial(downloadable) == 'font'

    font = font_assets(downloadable)
    {
      controller: 'font-preview resource-tabs',
      action: 'resource-tabs:shown->font-preview#tabShown',
      font_preview_font_url_value: font[:font_url],
      font_preview_font_format_value: font[:font_format],
      font_preview_font_face_value: font[:font_face],
      font_preview_sample_text_value: font[:sample_text]
    }
  end

  # Resources tagged with any of these go together, e.g. the Surah names
  # metadata and the fonts and images that draw surah names.
  COMPANION_TAGS = [
    %w[surah-name surah-names],
    %w[juz juz-names]
  ].freeze

  RELATED_LIMIT = 8

  # Linked resources (both directions) first, then companions found by tag.
  # Resources of a different type come before more of the same kind.
  def related_resources_for(downloadable = resource)
    linked = downloadable.related_resources.to_a +
             DownloadableResource.published.joins(:downloadable_related_resources)
                                 .where(downloadable_related_resources: { related_resource_id: downloadable.id }).to_a

    related = (linked + companion_resources(downloadable)).uniq.reject { |r| r.id == downloadable.id || !r.published? }
    related.sort_by.with_index { |r, i| [r.resource_type == downloadable.resource_type ? 1 : 0, i] }.first(RELATED_LIMIT)
  end

  # One or two sentences explaining what a resource type is, shown at the top
  # of the Preview tab when the resource has no description of its own.
  def preview_intro(downloadable = resource)
    return if downloadable.description.present?

    content = downloadable.resource_content
    name = downloadable.name

    case preview_partial(downloadable)
    when 'ayah_theme'
      'The theme of each passage of the Quran: a short summary of what a group of ayahs is about, with the ayah range it covers.'
    when 'ayah_topics'
      'Topics the Quran talks about and the ayahs that discuss each one, grouped into ontology, thematic and general topics.'
    when 'font'
      'Type in the box below to see how this font renders. The Glyphs tab lists every character the font contains.'
    when 'svg_images'
      'Each image is a plain SVG you can recolour and scale. Click one below to copy its URL.'
    when 'morphology'
      kind = content.meta_value('morphology-resource-type').to_s.downcase
      "The #{kind} of every word in the Quran. Pick an ayah to see each of its words with its #{kind}."
    when 'mushaf_layout'
      'Where every word sits on every page of this Mushaf, line by line, so you can rebuild the pages exactly as printed.'
    when 'mutashabihat'
      'Phrases that repeat across the Quran, with every ayah each one appears in. Helpful when memorising ayahs that are easy to mix up.'
    when 'quran_metadata'
      quran_metadata_intro(content)
    when 'quran_script'
      by = content.word? ? 'word by word' : 'ayah by ayah'
      "The text of the Quran, #{by}. It only displays correctly with the font it was made for."
    when 'recitation'
      unit = content.one_ayah? ? 'ayah' : 'surah'
      segments = downloadable.downloadable_resource_tags.any? { |tag| tag.slug == 'with-segments' }
      "Audio of the whole Quran recited by #{name.sub(/\s*recitation\z/i, '')}, one file per #{unit}" +
        (segments ? ', with timings for each word so you can highlight words as the audio plays.' : '.')
    when 'similar_ayah'
      'For each ayah, the other ayahs whose wording closely matches it.'
    when 'surah_info'
      'Background on each surah: its name, when and where it was revealed, and what it covers.'
    when 'tafsir'
      'Commentary explaining the meaning of the ayahs. One passage often covers several ayahs, so neighbouring ayahs can show the same text.'
    when 'translation'
      language = (content.language || downloadable.language)&.name
      if content.one_word?
        "The meaning of each word of the Quran#{" in #{language}" if language}."
      else
        "A translation of every ayah of the Quran#{" in #{language}" if language}."
      end
    when 'transliteration'
      unit = content.one_word? ? 'Each word' : 'Each ayah'
      "#{unit} of the Quran written in Latin letters, so readers who can't read Arabic script can follow the pronunciation."
    end
  end

  def resource_permission
    resource.resource_content&.resource_permission
  end

  # Font file, CSS format and sample text for a font resource. Shared by the
  # font preview and its docs tab.
  def font_assets(downloadable = resource)
    @font_assets ||= {}
    @font_assets[downloadable.id] ||= build_font_assets(downloadable)
  end

  def extra_detail_tabs(downloadable)
    return [] unless preview_partial(downloadable) == 'font'

    tabs = []
    if font_assets(downloadable)[:ligatures].present?
      tabs << DetailTab.new(key: 'ligatures', label: 'Ligatures', partial: 'resources/previews/font/ligatures')
    end
    tabs << DetailTab.new(key: 'glyphs', label: 'Glyphs', partial: 'resources/previews/font/glyphs')
  end

  def build_font_assets(downloadable)
    resource_content = downloadable.resource_content
    sample_text = resource_content.meta_value('text')
    font_face = resource_content.meta_value('font-face')

    font_base_path = resource_content.meta_value('ttf')
    font_format = 'ttf'
    font_extension = '.ttf'

    unless font_base_path.present?
      font_base_path = resource_content.meta_value('woff2')
      font_format = 'woff2'
      font_extension = '.woff2'
    end

    unless font_base_path.present?
      font_base_path = resource_content.meta_value('woff')
      font_format = 'woff'
      font_extension = '.woff'
    end

    unless font_base_path.present?
      font_base_path = resource_content.meta_value('otf')
      font_format = 'otf'
      font_extension = '.otf'
    end

    preview_pattern = resource_content.meta_value('preview-pattern') ||
                      resource_content.meta_value('preview_pattern')

    # V1/V2 Mushaf fonts ship one file per Quran page, named p1..p604 inside the
    # directory recorded in the meta. Their font-face is stored as "p1-v1".
    page_based_font = font_face.to_s.match?(/\Ap\d+-v/)
    page_number = nil
    total_pages = 604
    font_cdn = "#{ENV['CDN_HOST']}/qul/fonts/"

    if page_based_font
      page_number = params[:page].to_s.delete('^0-9').to_i
      page_number = 1 unless page_number.between?(1, total_pages)

      font_face = font_face.sub(/\Ap\d+/, "p#{page_number}")
      font_url = "#{font_cdn}#{font_base_path}/p#{page_number}#{font_extension}"

      mushaf_version = font_face[/-v(\d+)\z/, 1]
      page_column, line_column, text_column = if mushaf_version == '2'
        [:v2_page, :line_v2, :code_v2]
      else
        [:page_number, :line_number, :code_v1]
      end

      sample_text = Word.unscoped
                      .where(page_column => page_number)
                      .order(:word_index)
                      .pluck(line_column, text_column)
                      .group_by(&:first)
                      .map { |_line, words| words.map(&:last).join(' ') }
                      .join("\n")
    elsif preview_pattern.present?
      page_key = (params[:page].presence || 'p1').to_s
      preview_base = preview_pattern.sub(/p\d+$/, page_key)
      font_url = "#{font_cdn}#{preview_base}#{font_extension}"
    else
      font_url = "#{font_cdn}#{font_base_path}#{font_extension}"
    end

    css_format = { 'woff2' => 'woff2', 'woff' => 'woff', 'otf' => 'opentype' }.fetch(font_format, 'truetype')

    ligatures = resource_content.meta_value('ligatures')
    ligatures = Oj.load(ligatures) if ligatures.present?

    preview_text = params[:text].presence || sample_text

    {
      font_face: font_face,
      font_url: font_url,
      font_format: font_format,
      css_format: css_format,
      sample_text: sample_text,
      preview_text: preview_text,
      ligatures: ligatures,
      page_based_font: page_based_font,
      page_number: page_number,
      total_pages: total_pages
    }
  end

  # Determines which preview partial to render for resource.
  def preview_partial(downloadable = resource)
    content = downloadable.resource_content

    return 'svg_images' if content.image? && content.meta_value('svg-template').present?

    downloadable.resource_type.to_s.tr('-', '_')
  end

  def svg_image_urls(downloadable = resource)
    svg_image_paths(downloadable).map { |path| "#{QuranApiRecord::FONTS_CDN}/#{path}" }
  end

  def svg_image_paths(downloadable = resource)
    content = downloadable.resource_content
    template = content.meta_value('svg-template')
    return [] if template.blank?

    count = content.meta_value('svg-count').to_i
    first = (content.meta_value('svg-start').presence || 1).to_i

    (first...(first + count)).map do |number|
      template.sub(/#+/) { |digits| number.to_s.rjust(digits.length, '0') }
    end
  end

  def load_ayah(fallback_key: '1:1')
    @load_ayah ||= {}

    @load_ayah[fallback_key] ||= begin
      requested = params[:ayah].presence
      ayah = requested && Verse.includes(:chapter).find_by_id_or_key(requested)
      # Fall back to a known ayah when the requested one is missing or invalid,
      # meta tag generation can't work with a nil verse.
      ayah || Verse.includes(:chapter).find_by_id_or_key(fallback_key)
    end
  end

  def load_surah
    if v = load_ayah
      v.chapter
    end
  end

  def verse_number
    if v = load_ayah
      v.verse_number
    end
  end

  def clean_meta_description(text, max_length = 160)
    return "" if text.nil?

    # 1. Remove all HTML tags (including attributes)
    cleaned = text.gsub(/<[^>]*>/, "")

    # 2. Decode HTML entities (requires CGI)
    cleaned = CGI.unescapeHTML(cleaned)

    # 3. Normalize whitespace and line breaks
    cleaned = cleaned.gsub(/[\r\n]+/, "\n")

    # 4. If already short enough, return
    return cleaned if cleaned.length <= max_length

    # 5. Prefer sentence end before limit
    truncated = cleaned[0...max_length]
    if truncated =~ /(.*?[.!?])[^.!?]*$/
      return $1.strip
    end

    # 6. Otherwise cut at the last space
    truncated = truncated.rpartition(" ").first
    truncated.strip + "…"
  end

  def companion_resources(downloadable)
    tags = downloadable.downloadable_resource_tags.map(&:slug)
    group = COMPANION_TAGS.find { |slugs| (slugs & tags).any? }
    return [] unless group

    DownloadableResource.published
                        .joins(:downloadable_resource_tags)
                        .where(downloadable_resource_tags: { slug: group })
                        .where(resource_type: %w[font quran-metadata])
                        .distinct
                        .order(:id)
                        .to_a
  end

  def quran_metadata_intro(content)
    case content.name.downcase.gsub('name', '').strip
    when 'surah'
      'Names of all 114 surahs in Arabic and in Latin letters, with where and in what order each was revealed, how many ayahs it has and whether it starts with the Bismillah. To show surah names as calligraphy, use one of the surah name fonts or images under Related resources.'
    when 'ayah'
      'Every ayah of the Quran with its surah and ayah number, its key (such as 2:255), its word count and its plain text.'
    when 'sajda'
      'The ayahs where a prostration (sajdah) is made when reciting them, and whether each one is optional or required.'
    end
  end
end