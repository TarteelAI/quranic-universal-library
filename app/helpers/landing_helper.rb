module LandingHelper
  def featured_downlodable_resource_cards
    recitations = ResourceContent.approved.recitations
    with_segments = recitations.with_segments.count
    total_recitations = recitations.count

    total_layout = Mushaf.count
    approved_layout = Mushaf.approved.count

    [
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
        url: '/resources/mushaf-layouts',
        count: total_layout,
        type: 'card-mushaf-layouts',
        # TODO: once all layout are approved, stats will looks weird. Fix the messaging
        stats: "<div><div>#{approved_layout} Layouts —  Approved</div><div>#{total_layout - approved_layout} Layouts —  WIP</div></div>"
      )
    ]
  end

  def downlodable_resource_cards
    translations = ResourceContent.approved.translations
    wbw_translation = translations.one_word.count
    ayah_translation = translations.one_verse.count

    tafisrs = ResourceContent.tafsirs.approved

    [
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
      #TODO: use font/text svg and update stats
      ToolCard.new(
        title: "Quran script and fonts",
        description: "Download Quran text and fonts, Madani, IndoPak etc.",
        url: '/resources/quran-script',
        type: 'quranic-text',
        icon: 'bismillah.svg',
        count: 15,
        type: 'quranic-text',
        stats: "<div><div>Indopak</div><div>Uthmani, tajweed</div></div>"
      ),
      #TODO: update bg and svg
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
        title: "Quran metadata",
        description: "Download Mushaf layout data to render Quran pages exactly like the printed Mushaf. The exact layout aids in memorizing the Quran, offering users a familiar experience similar to their favorite printed Mushaf.",
        icon: 'layout.svg',
        url: '/resources/quran-metadata',
        count: Mushaf.approved.count,
        type: 'metadata'
      ),
      ToolCard.new(
        title: "Quranic Grammar and Morphology",
        description: "Quranic Grammar(part of speech for each word), morphology, roots, lemmas and stems data.",
        icon: 'layout.svg',
        url: '/resources/grammar-morphology',
        type: 'grammar-morphology',
      ),
      ToolCard.new(
        title: 'Mutashabihat ul Quran',
        description: 'Similarities in meaning, context, or wording among ayah phrases in the Quran.',
        url: '/resources/mutashabihat',
        type: 'mutashabihat',
        icon: 'mutashabihat.svg',
        cta_bg: 'rgba(56, 152, 173, 0.9)'
      ),
      ToolCard.new(
        title: 'Similiar ayahs',
        description: 'Download Ayahs from the Quran that share similarities in meaning, context, or wording. This data allows you to explore and access Ayahs that closely align with each other.',
        url: '/resources/similar-ayah',
        type: 'mutashabihat',
        icon: 'mutashabihat.svg',
        cta_bg: 'rgba(56, 152, 173, 0.9)'
      ),
      ToolCard.new(
        title: 'Ayah theme',
        description: 'Core themes and topics of each ayah in the Quran.',
        url: '/resources/ayah-theme',
        type: 'mutashabihat',
        icon: 'layout.svg',
        cta_bg: 'rgba(56, 152, 173, 0.9)'
      )
    ]
  end

  def developer_tools
    [
      ToolCard.new(
        title: 'Surah audio segments',
        description: 'Tool for creating word by word timestamp data of surah audio files.',
        url: '/surah_audio_files',
        type: 'segments',
        icon: 'timestamp.svg',
        cta_bg: 'rgba(56, 165, 126, 0.9)',
        info_tip: "Surah Timestamp Editor is designed to help you prepare precise timestamp data for surah audio files. This data empower Quranic apps to highlight the currently playing words in real-time."
      ),
      ToolCard.new(
        title: 'Prepare Mushaf layout',
        description: 'Proofread and fix different layouts of Mushaf( 15 lines, 16 lines, v2, v1 etc)',
        url: '/mushaf_layouts',
        type: 'mushaf-layout',
        icon: 'layout.svg',
        cta_bg: 'rgba(71, 71, 61, 0.9)',
        info_tip: "This feature allows you to view the digital Quran script as it appears in printed Mushafs. You can also customize and prepare layouts based on any printed Mushaf format."
      ),
      ToolCard.new(
        title: 'Mutashabihat ul Quran',
        description: 'Contribute preparing matching ayah and phrases data in Quran.',
        url: '/morphology_phrases',
        type: 'mutashabihat',
        icon: 'mutashabihat.svg',
        cta_bg: 'rgba(56, 152, 173, 0.9)',
        info_tip: "This tool allows you to identify and compare verses and phrases that share similarities in meaning, context, or wording."
      ),
      ToolCard.new(
        title: 'Ayah audio segments',
        description: 'Tool for creating word by word segments of ayah by ayah audio files.',
        url: '/ayah_audio_files',
        type: 'segments',
        icon: 'timestamp.svg',
        cta_bg: 'rgba(56, 165, 126, 0.9)',
        info_tip: "Ayah Timestamp Editor is designed to help you prepare precise timestamp data for ayah audio files. This data empower Quranic apps to highlight the currently playing words in real-time."
      ),
      ToolCard.new(
        title: 'Ayah translation in different languages',
        description: 'Tool for proofreading and suggesting fixes for ayah translations.',
        url: '/ayah_audio_files',
        type: 'translation',
        icon: 'translation.svg',
        cta_bg: 'rgba(90, 77, 65, 0.9)',
        info_tip: "This tool helps you review and suggest fixes for Quran translations, including typos and issues that may occur during OCR (Optical Character Recognition) or due to human error."
      ),
      ToolCard.new(
        title: 'Quranic script and fonts',
        description: 'Proofread tashkeel issues of Quran script for different fonts.',
        url: '/word_text_proofreadings',
        type: 'quranic-text',
        icon: 'open_book.svg',
        cta_bg: 'rgba(56, 165, 126, 0.9)',
        info_tip: "This tool enables you to proofread Quran script rendering in various fonts, examining it both ayah by ayah and word by word. Ensure that the script is accurately rendered and consistent across different fonts for a seamless reading experience.",
      )
    ]
  end

  def developer_resources
    [
      ToolCard.new(
        title: 'Download Quran Translation',
        description: 'Download ayah by ayah and word by word translation in different languages.',
        url: '/resources/translation',
        type: 'translation',
        icon: 'translation.svg',
        cta_bg: 'rgba(90, 77, 65, 0.9)',
      ),
      ToolCard.new(
        title: 'Audio files and segments data',
        description: 'Download surah by surah, ayah by ayah and word by word audio files and segments data.',
        url: '/resources/recitation',
        type: 'segments',
        icon: 'timestamp.svg',
        cta_bg: 'rgba(56, 165, 126, 0.9)',
      ),
      ToolCard.new(
        title: 'Quranic script and fonts',
        description: 'Download Quran text and fonts, Madani, IndoPak etc.',
        url: '/resources/quran-text',
        type: 'quranic-text',
        icon: 'open_book.svg',
        cta_bg: 'rgba(56, 165, 126, 0.9)',
      ),
      ToolCard.new(
        title: 'Prepare Mushaf layout',
        description: 'Proofread and fix different layouts of Mushaf( 15 lines, 16 lines, v2, v1 etc)',
        url: '/mushaf_layouts',
        type: 'page-layout',
        icon: 'layout.svg',
        cta_bg: 'rgba(71, 71, 61, 0.9)'
      ),
      ToolCard.new(
        title: 'Mutashabihat ul Quran Data',
        description: 'Download Mutashabihat ul Quran data, featuring the similar or analogous phrases found throughout the Quran.',
        url: '/morphology_phrases',
        type: 'mutashabihat',
        icon: 'mutashabihat.svg',
        cta_bg: 'rgba(56, 152, 173, 0.9)',
      ),
      ToolCard.new(
        title: 'Tafsirs',
        description: 'Download tafsir data in multiple languages, with ayah grouping information.',
        url: '/resources/tafisr',
        type: 'tafsirs',
        icon: 'book.svg',
        cta_bg: 'rgba(56, 165, 126, 0.9)'
      )
    ]
  end
end