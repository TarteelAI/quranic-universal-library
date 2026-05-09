module ResourcesHelper
  RESOURCE_TYPE_LABELS = {
    'ayah-theme' => 'Ayah Theme',
    'ayah-topics' => 'Ayah Topics',
    'font' => 'Font',
    'morphology' => 'Morphology',
    'mushaf-layout' => 'Mushaf Layout',
    'mutashabihat' => 'Mutashabihat',
    'quran-metadata' => 'Quran Metadata',
    'quran-script' => 'Quran Script',
    'recitation' => 'Recitation',
    'similar-ayah' => 'Similar Ayah',
    'surah-info' => 'Surah Info',
    'tafsir' => 'Tafsir',
    'translation' => 'Translation',
    'transliteration' => 'Transliteration'
  }.freeze

  def downloadable_resource_cards
    return @downloadable_resource_cards if @downloadable_resource_cards

    recitations = ResourceContent.approved.recitations
    with_segments = recitations.with_segments.count
    total_recitations = recitations.count

    total_layout = Mushaf.count
    approved_layout = Mushaf.approved.count

    translations = ResourceContent.approved.translations
    wbw_translation = translations.one_word.count
    ayah_translation = translations.one_verse.count
    transliteration_count = ResourceContent.transliteration.approved.count

    tafisrs = ResourceContent.tafsirs.approved

    @downloadable_resource_cards = {
      recitation: ToolCard.new(
        title: 'Recitations and segments data',
        description: "Download high-quality audio files of Quranic recitations along with detailed timestamp data for ayah-by-ayah and surah-by-surah. Use the timestamp data to highlight words as the recitation plays.",
        icon: 'timestamp.svg',
        list_icon: 'volume.svg',
        url: '/resources/recitation',
        count: total_recitations,
        type: 'card-recitations',
        stats: "<div><div>#{total_recitations - with_segments} Unsegmented Audio</div><div>#{with_segments} Segmented Audio</div></div>"
      ),
      mushaf_layout: ToolCard.new(
        title: "Mushaf layouts",
        description: "Download Mushaf layout data to render Quran pages exactly like the printed Mushaf. The exact layout aids in memorizing the Quran, offering users a familiar experience similar to their favorite printed Mushaf.",
        icon: 'layout.svg',
        list_icon: 'layout.svg',
        url: '/resources/mushaf-layout',
        count: total_layout,
        type: 'card-mushaf-layouts',
        stats: "<div><div>#{approved_layout} Layouts —  Approved</div><div>#{total_layout - approved_layout} Layouts —  WIP</div></div>"
      ),
      translation: ToolCard.new(
        title: 'Translations',
        description: "Download ayah by ayah and word by word translation in different languages.",
        page_description: "This page has Quran translations in multiple languages, available for both Ayah-by-Ayah and Word-by-Word formats. Translation are available in different structures and file formats, including JSON, CSV, and SQL. <a href='#' class='btn-link text-dark text-decoration-underline' data-controller='ajax-modal' data-url='/docs/translation_formats' data-css-class='modal-lg'>Click here</a> for more information about data structures.",
        icon: 'translation.svg',
        list_icon: 'page.svg',
        url: '/resources/translation',
        count: wbw_translation + ayah_translation,
        type: 'translation',
        stats: "<div><div>#{ayah_translation} Translations</div><div>#{wbw_translation} Word by word translations</div></div>"
      ),

      tafsir: ToolCard.new(
        title: "Tafsirs",
        description: "Download tafsir data in multiple languages, with ayah grouping information.",
        icon: 'open_book.svg',
        list_icon: 'tafsir.svg',
        url: '/resources/tafsir',
        count: tafisrs.count,
        type: 'tafsirs',
        stats: "<div><div>#{tafisrs.mukhtasar_tafisr.count} Mukhtasar tafsirs</div><div>#{tafisrs.count - tafisrs.mukhtasar_tafisr.count} Detailed tafsirs</div></div>"
      ),

      quran_script: ToolCard.new(
        title: "Quran script: Unicode & Images",
        description: "Download the Quran script in Unicode text or image formats, including Madani, IndoPak, and Uthmani scripts.",
        url: '/resources/quran-script',
        type: 'quranic-text',
        icon: 'bismillah.svg',
        list_icon: 'font.svg',
        count: DownloadableResource.quran_script.published.count,
        stats: "<div><div>Indopak</div><div>Uthmani, tajweed</div></div>"
      ),

      font: ToolCard.new(
        title: "Quran Fonts",
        description: "Download Quran-related fonts, including glyph-based, Unicode, and translation fonts. Also includes specialized fonts for Surah names and headings.",
        url: '/resources/font',
        type: 'fonts',
        icon: 'quran.svg',
        list_icon: 'font.svg',
        count: ResourceContent.fonts.approved.size,
        stats: "<div><div>Indopak</div><div>Madani</div></div>"
      ),

      quran_metadata: ToolCard.new(
        title: "Quran metadata",
        description: "Download Quran metadata, surah, ayah, juz, hizb, rub, manzil etc.",
        url: '/resources/quran-metadata',
        type: 'metadata',
        icon: 'bismillah.svg',
        list_icon: 'page.svg',
        count: ResourceContent.quran_metadata.count,
        stats: "<div><div>Total resources</div></div>"
      ),

      transliteration: ToolCard.new(
        title: "Transliteration",
        description: "Download transliteration data to read the Quranic text in Latin script.",
        icon: 'transliteration.svg',
        list_icon: 'translate.svg',
        url: '/resources/transliteration',
        count: transliteration_count,
        type: 'transliteration',
        stats: "<div><div>#{transliteration_count - 1} Ayah by Ayah</div><div>1 Word by Word</div></div>"
      ),

      surah_info: ToolCard.new(
        title: "Surah information",
        description: "Detailed descriptions of all Surah, including when they were revealed, core themes, and key topics etc.",
        icon: 'layout.svg',
        list_icon: 'page.svg',
        url: '/resources/surah-info',
        count: ResourceContent.chapter_info.count,
        type: 'surah-info',
        stats: "<div><div>In #{ResourceContent.chapter_info.count} Languages</div></div>"
      ),

      ayah_topics: ToolCard.new(
        title: "Topics and concepts in the Quran",
        description: "Key concepts/topics in the Quran and semantic relations between these concepts.",
        icon: 'layout.svg',
        list_icon: 'topic.svg',
        url: '/resources/ayah-topics',
        count: Topic.count,
        type: 'ayah-topics',
        stats: "<div><div>#{Topic.count} topics</div></div>"
      ),

      morphology: ToolCard.new(
        title: "Quranic Grammar and Morphology",
        description: "Quranic Grammar (part of speech for each word), morphology, roots, lemmas and stems data.",
        icon: 'layout.svg',
        url: '/resources/morphology',
        type: 'grammar-morphology',
        count: WordCorpus.count
      ),

      mutashabihat: ToolCard.new(
        title: 'Mutashabihat ul Quran',
        description: 'Similarities in meaning, context, or wording among ayah phrases in the Quran.',
        url: '/resources/mutashabihat',
        type: 'mutashabihat',
        icon: 'mutashabihat.svg',
        list_icon: 'mutashabihat.svg',
        count: Morphology::Phrase.approved.count
      ),

      similar_ayah: ToolCard.new(
        title: 'Similiar ayahs',
        description: 'Download Ayahs from the Quran that share similarities in meaning, context, or wording. This data allows you to explore and access Ayahs that closely align with each other.',
        url: '/resources/similar-ayah',
        type: 'mutashabihat',
        icon: 'mutashabihat.svg',
        list_icon: 'similar.svg',
        count: Morphology::MatchingVerse.approved.count
      ),

      ayah_theme: ToolCard.new(
        title: 'Ayah theme',
        description: 'Core themes and topics of each ayah in the Quran.',
        url: '/resources/ayah-theme',
        type: 'mutashabihat',
        icon: 'layout.svg',
        list_icon: 'topic.svg',
        count: AyahTheme.count
      )
    }
  end

  def featured_developer_tools
    developer_tools.first(8)
  end

  def featured_developer_resources
    downloadable_resource_cards.values
  end

  def current_resources_page_path(overrides = {})
    query_params = normalized_resource_query_params(overrides)

    if action_name == 'show'
      resource_path(params[:id], query_params)
    else
      resources_path(query_params)
    end
  end

  def resource_search_clear_path
    preserved = {}
    preserved[:view] = params[:view] if params[:view].present?
    current_resources_page_path(preserved.merge(q: nil, tags: [], resource_types: []))
  end

  def resource_search_toggle_tag_path(tag_name)
    tags = Array(params[:tags]).map(&:to_s)
    normalized_name = tag_name.to_s

    if tags.include?(normalized_name)
      tags -= [normalized_name]
    else
      tags << normalized_name
    end

    current_resources_page_path(tags: tags)
  end

  def resource_search_remove_tag_path(tag_name)
    tags = Array(params[:tags]).map(&:to_s) - [tag_name.to_s]
    current_resources_page_path(tags: tags)
  end

  def resource_search_toggle_type_path(resource_type)
    resource_types = Array(params[:resource_types]).map(&:to_s)
    normalized_type = resource_type.to_s

    if resource_types.include?(normalized_type)
      resource_types -= [normalized_type]
    else
      resource_types << normalized_type
    end

    current_resources_page_path(resource_types: resource_types)
  end

  def resource_search_remove_type_path(resource_type)
    resource_types = Array(params[:resource_types]).map(&:to_s) - [resource_type.to_s]
    current_resources_page_path(resource_types: resource_types)
  end

  def resource_type_label(resource_type)
    RESOURCE_TYPE_LABELS.fetch(resource_type.to_s) do
      resource_type.to_s.tr('-', ' ').titleize
    end
  end

  def resource_search_detail_path(resource, search_result = @resource_search)
    detail_params = {}
    detail_params[:ayah] = search_result.normalized_ayah if search_result&.normalized_ayah.present?
    detail_resources_path(resource.resource_type, resource.to_param, detail_params)
  end

  private

  def normalized_resource_query_params(overrides = {})
    query_params = request.query_parameters.symbolize_keys
    merged = query_params.merge(overrides.symbolize_keys)

    merged[:tags] = Array(merged[:tags]).map(&:to_s).reject(&:blank?).uniq if merged.key?(:tags)
    merged[:resource_types] = Array(merged[:resource_types]).map(&:to_s).reject(&:blank?).uniq if merged.key?(:resource_types)
    merged.delete_if { |_key, value| value.respond_to?(:empty?) ? value.empty? : value.nil? }
    merged
  end
end
