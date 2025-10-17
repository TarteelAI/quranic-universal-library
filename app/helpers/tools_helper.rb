module ToolsHelper
  def developer_tools
    [
      ToolCard.new(
        title: 'Prepare Mushaf layout',
        description: 'Proofread and fix different layouts of Mushaf (15 lines, 16 lines, v2, v1 etc)',
        url: '/mushaf_layouts',
        type: 'mushaf-layout',
        icon: 'layout.svg',
        tags: [['Mushaf Layout', 'mushaf-layout']],
        info_tip: "This tool allows you to create the digital Quran layout as it appears in printed Mushafs."
      ),
      ToolCard.new(
        title: 'Tajweed Rules Annotation Tool',
        description: 'Review and correct the Tajweed rules embedded in Quranic text',
        url: tajweed_words_path,
        type: 'tajweed-tool',
        icon: 'tajweed.svg',
        tags: [['Tajweed', 'tajweed']],
        info_tip: "Use Tajweed Tools to locate words with specific Tajweed rules, receive suggestions for missing rules, add the missing or fix the incorrect one."
      ),
      ToolCard.new(
        title: 'Mutashabihat ul Quran',
        description: 'Contribute preparing matching ayah and phrases data in Quran.',
        url: '/morphology_phrases',
        type: 'mutashabihat',
        icon: 'mutashabihat.svg',
        cta_bg: 'rgba(56, 152, 173, 0.9)',
        tags: [['Mutashabihat', 'mutashabihat']],
        info_tip: "This tool allows you to identify and compare verses and phrases that share similarities in meaning, context, or wording."
      ),
      ToolCard.new(
        title: 'Surah audio segments',
        description: 'Tool for creating word by word timestamp data of surah audio files.',
        url: '/surah_audio_files',
        type: 'segments',
        tags: [['Recitation', 'recitation'], ['Surah by Surah', 'surah-by-surah'], ['Timestamp', 'timestamp']],
        icon: 'timestamp.svg',
        cta_bg: 'rgba(56, 165, 126, 0.9)',
        info_tip: "Surah Timestamp Editor is designed to help you prepare precise timestamp data for surah audio files. This data empower Quranic apps to highlight the currently playing words in real-time."
      ),
      ToolCard.new(
        title: 'Ayah audio segments',
        description: 'Tool for creating word by word segments of ayah by ayah audio files.',
        url: '/ayah_audio_files',
        type: 'segments',
        tags: [['Recitation', 'recitation'], ['Ayah by Ayah', 'ayah-by-ayah'], ['Timestamp', 'timestamp']],
        icon: 'timestamp.svg',
        cta_bg: 'rgba(56, 165, 126, 0.9)',
        info_tip: "Ayah Timestamp Editor is designed to help you prepare precise timestamp data for ayah audio files. This data empower Quranic apps to highlight the currently playing words in real-time."
      ),
      ToolCard.new(
        title: 'Ayah translation in different languages',
        description: 'Tool for proofreading and suggesting the fixes for ayah translations.',
        url: translation_proofreadings_path,
        type: 'translation',
        tags: [['Translation', 'translation']],
        icon: 'translation.svg',
        cta_bg: 'rgba(90, 77, 65, 0.9)',
        info_tip: "This tool helps you review and suggest fixes for Quran translations, including typos and issues that may occur during OCR (Optical Character Recognition) or due to human error."
      ),
      ToolCard.new(
        title: 'Ayah tafsirs in different languages',
        description: 'Tool for proofreading and suggesting the fixes for ayah tafsirs.',
        url: tafsir_proofreadings_path,
        type: 'tafsir',
        tags: [['Tafsir', 'tafsir']],
        icon: 'translation.svg',
        cta_bg: 'rgba(90, 77, 65, 0.9)',
        info_tip: "This tool helps you review and suggest fixes for Quran tafsirs, including typos and issues that may occur during OCR (Optical Character Recognition) or due to human error."
      ),
      ToolCard.new(
        title: 'Quranic script and fonts',
        description: 'Proofread tashkeel issues in Quran script for different fonts.',
        url: '/word_text_proofreadings',
        type: 'quranic-text',
        icon: 'open_book.svg',
        tags: [['Quran Script', 'quran-script'], ['Fonts', 'fonts']],
        cta_bg: 'rgba(56, 165, 126, 0.9)',
        info_tip: "This tool enables you to proofread Quran script( For Tashkeel issues and font compatibility), both ayah by ayah and word by word.",
      ),
      ToolCard.new(
        title: 'Surah Info in different languages',
        description: 'Proofread and suggest fixes for Surah information in different languages.',
        url: surah_infos_path,
        type: 'segments',
        icon: 'timestamp.svg',
        tags: [['Surah info', 'surah-info']],
        cta_bg: 'rgba(56, 165, 126, 0.9)',
        info_tip: "This tool allow you to proofread Surah info in different languages."
      ),
      ToolCard.new(
        title: 'Arabic/Urdu syllable of Quran words',
        description: 'Transliteration of each word of Quran in Arabic and Urdu.',
        url: arabic_transliterations_path,
        type: 'corpus',
        tags: [['Transliteration', 'transliteration'], ['Word by Word', 'word-by-word']],
        icon: 'qaf.svg',
        cta_bg: 'rgba(56, 165, 126, 0.9)',
        info_tip: "This tool allow you to prepare Arabic transliterations(syllable)."
      ),
      ToolCard.new(
        title: 'Word by Word translation',
        description: 'Proofread and suggest fixes for word by word translations in multiple languages.',
        url: word_translations_path,
        type: 'corpus',
        tags: [['Translation', 'translation'], ['Word by Word', 'word-by-word']],
        icon: 'timestamp.svg',
        cta_bg: 'rgba(56, 165, 126, 0.9)',
        info_tip: "This tool is used to proofread and fix word-by-word translations"
      ),
      ToolCard.new(
        title: 'Concordance labeling of each word',
        description: 'Help us fix grammar, part of speech, and morphology data for each word of Quran.',
        url: word_concordance_labels_path,
        type: 'corpus',
        tags: [['Corpus', 'corpus'], ['Grammar', 'quranic-grammar'], ['POS', 'part-of-speech'], ['Morphology', 'quranic-morphology']],
        icon: 'tags.svg',
        cta_bg: 'rgba(56, 165, 126, 0.9)',
        info_tip: "This tool is used to tag part of speech, grammar of each word of Quran."
      ),
      ToolCard.new(
        title: 'Text unicode value',
        description: 'See details of each letter in Arabic text of Quran.',
        url: chars_info_path,
        type: 'corpus',
        tags: ['Letter Info'],
        icon: 'info.svg',
        cta_bg: 'rgba(56, 165, 126, 0.9)',
        info_tip: "This tool helps you detect unicode value of any character, and is being used to debug the font issues."
      ),
      ToolCard.new(
        title: 'Compare ayah',
        description: 'Compare ayahs',
        url: compare_ayah_path,
        type: 'ayah-reader',
        icon: 'compare.svg',
        tags: [],
        info_tip: 'Compare multiple Ayahs, with optional translations to find differences or similarities in the script.',
      ),
      ToolCard.new(
        title: 'Audio Segmentations',
        description: 'This tool is used to inspect and validate the raw segmentation data of recitations by viewing detailed statistics, testing real-time word highlighting, and identifying missing or misaligned words.',
        url: segments_dashboard_path,
        type: 'segments',
        icon: 'timestamp.svg',
        tags: [['Timestamp', 'timestamp']],
        info_tip: 'Review and validate raw audio segmentation data of recitations.',
      ),
      ToolCard.new(
        title: 'Compare audio',
        description: 'Compare audio recitations',
        url: '/compare-audio',
        type: 'segments',
        icon: 'timestamp.svg',
        tags: [['Timestamp', 'timestamp']],
        info_tip: 'This tool is used to compare two audio recitations through waveform visualizations, helping identify differences and similarities between them.',
      ),
      ToolCard.new(
        title: 'Ayah Boundary Visualizer',
        description: 'This tool visualizes ayah start and end times as timeline bars, helping to debug and refine ayah boundary data derived from raw segmentation.',
        url: '/ayah-boundaries',
        type: 'segments',
        icon: 'timeline.svg',
        tags: [['Timestamp', 'timestamp']],
        info_tip: 'This tool visualizes ayah boundaries from raw segments data.'
      )
    ]
  end
end
