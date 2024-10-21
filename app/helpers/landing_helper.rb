module LandingHelper
  def featured_downloadable_resource_cards
    return @featured_downloadable_resource_cards if @featured_downloadable_resource_cards

    recitations = ResourceContent.approved.recitations
    with_segments = recitations.with_segments.count
    total_recitations = recitations.count

    total_layout = Mushaf.count
    approved_layout = Mushaf.approved.count

    @featured_downloadable_resource_cards = [
      ToolCard.new(
        title: 'Recitations and segments data',
        description: "Download high-quality audio files of Quranic recitations along with detailed timestamp data for ayah-by-ayah and surah-by-surah. Use the timestamp data to highlight words as the recitation plays.",
        icon: 'timestamp.svg',
        url: '/resources/recitation',
        count: total_recitations,
        type: 'card-recitations',
        stats: "<div><div>#{total_recitations - with_segments} Unsegmented Audio</div><div>#{with_segments} Segmented Audio</div></div>"
      ),
      ToolCard.new(
        title: "Mushaf layouts",
        description: "Download Mushaf layout data to render Quran pages exactly like the printed Mushaf. The exact layout aids in memorizing the Quran, offering users a familiar experience similar to their favorite printed Mushaf.",
        icon: 'layout.svg',
        url: '/resources/mushaf-layout',
        count: total_layout,
        type: 'card-mushaf-layouts',
        stats: "<div><div>#{approved_layout} Layouts —  Approved</div><div>#{total_layout - approved_layout} Layouts —  WIP</div></div>"
      )
    ]
  end

  def downloadable_resource_cards
    return @downloadable_resource_cards if @downloadable_resource_cards

    translations = ResourceContent.approved.translations
    wbw_translation = translations.one_word.count
    ayah_translation = translations.one_verse.count

    tafisrs = ResourceContent.tafsirs.approved

    @downloadable_resource_cards = [
      ToolCard.new(
        title: 'Translations',
        description: "Download ayah by ayah and word by word translation in different languages.",
        icon: 'translation.svg',
        url: '/resources/translation',
        count: wbw_translation + ayah_translation,
        type: 'translation',
        stats: "<div><div>#{ayah_translation} Translations</div><div>#{wbw_translation} Word by word translations</div></div>"
      ),
      ToolCard.new(
        title: "Tafsirs",
        description: "Download tafsir data in multiple languages, with ayah grouping information.",
        icon: 'open_book.svg',
        url: '/resources/tafsir',
        count: tafisrs.count,
        type: 'tafsirs',
        stats: "<div><div>#{tafisrs.mukhtasar_tafisr.count} Mukhtasar tafsirs</div><div>#{tafisrs.count - tafisrs.mukhtasar_tafisr.count} Detailed tafsirs</div></div>"
      ),
      ToolCard.new(
        title: "Quran script: Unicode & Images",
        description: "Download the Quran script in Unicode text or image formats, including Madani, IndoPak, and Uthmani scripts.",
        url: '/resources/quran-script',
        type: 'quranic-text',
        icon: 'bismillah.svg',
        count: 15,
        stats: "<div><div>Indopak</div><div>Uthmani, tajweed</div></div>"
      ),

      ToolCard.new(
        title: "Quran Fonts",
        description: "Download a variety of Quran fonts, including handwritten glyph-based and standard fonts for Unicode text.",
        url: '/resources/font',
        type: 'fonts',
        icon: 'quran.svg',
        count: ResourceContent.fonts.size,
        stats: "<div><div>Indopak</div><div>Madani</div></div>"
      ),

      ToolCard.new(
        title: "Quran metadata",
        description: "Download Quran metadata, surah, ayah, juz, hizb, rub, manzil etc.",
        url: '/resources/quran-metadata',
        type: 'metadata',
        icon: 'bismillah.svg',
        count: ResourceContent.quran_metadata.count,
        stats: "<div><div>Total resources</div></div>"
      ),
      # TODO: update bg and svg
      ToolCard.new(
        title: "Transliteration",
        description: "Download transliteration data to read the Quranic text in Latin script.",
        icon: 'transliteration.svg',
        url: '/resources/transliteration',
        count: ResourceContent.transliteration.approved.count,
        type: 'transliteration',
        stats: "<div><div>1 Ayah by ayah</div><div>2 Word by word</div></div>"
      ),
      ToolCard.new(
        title: "Surah information",
        description: "Detailed descriptions of all Surah, including when they were revealed, core themes, and key topics etc.",
        icon: 'layout.svg',
        url: '/resources/surah-info',
        count: ResourceContent.chapter_info.count,
        type: 'surah-info',
        stats: "<div><div>In #{ResourceContent.chapter_info.count} Languages</div></div>"
      ),
      ToolCard.new(
        title: "Topics and concepts in the Quran",
        description: "Key concepts/topics in the Quran and semantic relations between these concepts.",
        icon: 'layout.svg',
        url: '/resources/ayah-topics',
        count: Topic.count,
        type: 'ayah-topics',
        stats: "<div><div>#{Topic.count} topics</div></div>"
      ),
      ToolCard.new(
        title: "Quranic Grammar and Morphology",
        description: "Quranic Grammar(part of speech for each word), morphology, roots, lemmas and stems data.",
        icon: 'layout.svg',
        url: '/resources/morphology',
        type: 'grammar-morphology',
      ),
      ToolCard.new(
        title: 'Mutashabihat ul Quran',
        description: 'Similarities in meaning, context, or wording among ayah phrases in the Quran.',
        url: '/resources/mutashabihat',
        type: 'mutashabihat',
        icon: 'mutashabihat.svg',
      ),
      ToolCard.new(
        title: 'Similiar ayahs',
        description: 'Download Ayahs from the Quran that share similarities in meaning, context, or wording. This data allows you to explore and access Ayahs that closely align with each other.',
        url: '/resources/similar-ayah',
        type: 'mutashabihat',
        icon: 'mutashabihat.svg',
      ),
      ToolCard.new(
        title: 'Ayah theme',
        description: 'Core themes and topics of each ayah in the Quran.',
        url: '/resources/ayah-theme',
        type: 'mutashabihat',
        icon: 'layout.svg',
      )
    ]
  end

  def featured_developer_tools
    developer_tools.first(8)
  end

  def featured_developer_resources
    featured_downloadable_resource_cards + downloadable_resource_cards.first(5)
  end
end
