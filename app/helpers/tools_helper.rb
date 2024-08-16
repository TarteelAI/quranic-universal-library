module ToolsHelper
  def developer_tools
    [
      ToolCard.new(
        title: 'Prepare Mushaf layout',
        description: 'Proofread and fix different layouts of Mushaf( 15 lines, 16 lines, v2, v1 etc)',
        url: '/mushaf_layouts',
        type: 'mushaf-layout',
        icon: 'layout.svg',
        cta_bg: 'rgba(71, 71, 61, 0.9)',
        tags: ['Mushaf layout'],
        info_tip: "This tool allows you to create the digital Quran layout as it appears in printed Mushafs."
      ),
      ToolCard.new(
        title: 'Mutashabihat ul Quran',
        description: 'Contribute preparing matching ayah and phrases data in Quran.',
        url: '/morphology_phrases',
        type: 'mutashabihat',
        icon: 'mutashabihat.svg',
        cta_bg: 'rgba(56, 152, 173, 0.9)',
        tags: ['Mutashabihat'],
        info_tip: "This tool allows you to identify and compare verses and phrases that share similarities in meaning, context, or wording."
      ),
      ToolCard.new(
        title: 'Surah audio segments',
        description: 'Tool for creating word by word timestamp data of surah audio files.',
        url: '/surah_audio_files',
        type: 'segments',
        tags: ['Audio', 'Surah by surah', 'Timestamp'],
        icon: 'timestamp.svg',
        cta_bg: 'rgba(56, 165, 126, 0.9)',
        info_tip: "Surah Timestamp Editor is designed to help you prepare precise timestamp data for surah audio files. This data empower Quranic apps to highlight the currently playing words in real-time."
      ),
      ToolCard.new(
        title: 'Ayah audio segments',
        description: 'Tool for creating word by word segments of ayah by ayah audio files.',
        url: '/ayah_audio_files',
        type: 'segments',
        tags: ['Audio', 'ayah by ayah', 'Timestamp'],
        icon: 'timestamp.svg',
        cta_bg: 'rgba(56, 165, 126, 0.9)',
        info_tip: "Ayah Timestamp Editor is designed to help you prepare precise timestamp data for ayah audio files. This data empower Quranic apps to highlight the currently playing words in real-time."
      ),
      ToolCard.new(
        title: 'Ayah translation in different languages',
        description: 'Tool for proofreading and suggesting the fixes for ayah translations.',
        url: translation_proofreadings_path,
        type: 'translation',
        tags: ['translation'],
        icon: 'translation.svg',
        cta_bg: 'rgba(90, 77, 65, 0.9)',
        info_tip: "This tool helps you review and suggest fixes for Quran translations, including typos and issues that may occur during OCR (Optical Character Recognition) or due to human error."
      ),
      ToolCard.new(
        title: 'Ayah tafisrs in different languages',
        description: 'Tool for proofreading and suggesting the fixes for ayah tafisrs.',
        url: tafsir_proofreadings_path,
        type: 'tafsir',
        tags: ['tafsir'],
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
        tags: ['Quran script', 'Fonts'],
        cta_bg: 'rgba(56, 165, 126, 0.9)',
        info_tip: "This tool enables you to proofread Quran script( For Tashkeel issues and font compatibility), both ayah by ayah and word by word.",
        ),
      ToolCard.new(
        title: 'Surah Info in different languages',
        description: 'Proofread and suggest fixes for Surah information in different languages.',
        url: surah_infos_path,
        type: 'segments',
        icon: 'timestamp.svg',
        tags: ['Surah info'],
        cta_bg: 'rgba(56, 165, 126, 0.9)',
        info_tip: "This tool allow you to proofread Surah info in different languages."
      ),
      ToolCard.new(
        title: 'Arabic/Urdu syllable of Quran words',
        description: 'Transliteration of each word of Quran in Arabic and Urdu.',
        url: arabic_transliterations_path,
        type: 'corpus',
        tags: ['Transliteration', 'Arabic', 'Word by word'],
        icon: 'qaf.svg',
        cta_bg: 'rgba(56, 165, 126, 0.9)',
        info_tip: "This tool allow you to prepare Arabic transliterations(syllable)."
      ),
      ToolCard.new(
        title: 'Word by word translation',
        description: 'Proofread and suggest fixes for word by word translations in multiple languages.',
        url: word_translations_path,
        type: 'corpus',
        tags: ['Translation', 'Word by word'],
        icon: 'timestamp.svg',
        cta_bg: 'rgba(56, 165, 126, 0.9)',
        info_tip: "This tool is used to proofread and fix word-by-word translations"
      ),
      ToolCard.new(
        title: 'Concordance labeling of each word',
        description: 'Help us fix grammar, part of speech, and morphology data for each word of Quran.',
        url: word_concordance_labels_path,
        type: 'corpus',
        tags: ['Corpus', 'Grammar', 'POS', 'Morphology'],
        icon: 'tags.svg',
        cta_bg: 'rgba(56, 165, 126, 0.9)',
        info_tip: "This tool is used to tag part of speech, grammar of each word of Quran."
      ),
      ToolCard.new(
        title: 'Text unicode value',
        description: 'See details of each letter in Arabic text of Quran.',
        url: chars_info_path,
        type: 'corpus',
        tags: ['Letter info'],
        icon: 'info.svg',
        cta_bg: 'rgba(56, 165, 126, 0.9)',
        info_tip: "This tool helps you detect unicode value of any character, and is being used to debug the font issues."
      )
    ]
  end
end