module ToolsHelper
  def developer_tools
    [
      ToolCard.new(
        title: 'Mushaf layouts',
        description: 'Proofread and fix different layouts of Mushaf (15 lines, 16 lines, v2, v1 etc)',
        url: '/mushaf_layouts',
        type: 'mushaf-layout',
        icon: 'layout.svg',
        tags: [['Mushaf Layout', 'mushaf-layout']]
      ),
      ToolCard.new(
        title: 'Tajweed Rules Annotation Tool',
        description: 'Review and correct the Tajweed rules embedded in Quranic text',
        url: tajweed_words_path,
        type: 'tajweed-tool',
        icon: 'tajweed.svg',
        tags: [['Tajweed', 'tajweed']]
      ),
      ToolCard.new(
        title: 'Mutashabihat ul Quran',
        description: 'Contribute preparing matching ayah and phrases data in Quran.',
        url: '/morphology_phrases',
        type: 'mutashabihat',
        icon: 'mutashabihat.svg',
        cta_bg: 'rgba(56, 152, 173, 0.9)',
        tags: [['Mutashabihat', 'mutashabihat']]
      ),
      ToolCard.new(
        title: 'Surah audio segments',
        description: 'Tool for creating word by word timestamp data of surah audio files.',
        url: '/surah_audio_files',
        type: 'segments',
        tags: [['Recitation', 'recitation'], ['Surah by Surah', 'surah-by-surah'], ['Timestamp', 'timestamp']],
        icon: 'timestamp.svg',
        cta_bg: 'rgba(56, 165, 126, 0.9)'
      ),
      ToolCard.new(
        title: 'Ayah audio segments',
        description: 'Tool for creating word by word segments of ayah by ayah audio files.',
        url: '/ayah_audio_files',
        type: 'segments',
        tags: [['Recitation', 'recitation'], ['Ayah by Ayah', 'ayah-by-ayah'], ['Timestamp', 'timestamp']],
        icon: 'timestamp.svg',
        cta_bg: 'rgba(56, 165, 126, 0.9)'
      ),
      ToolCard.new(
        title: 'Ayah translation in different languages',
        description: 'Tool for proofreading and suggesting the fixes for ayah translations.',
        url: translation_proofreadings_path,
        type: 'translation',
        tags: [['Translation', 'translation']],
        icon: 'translation.svg',
        cta_bg: 'rgba(90, 77, 65, 0.9)'
      ),
      ToolCard.new(
        title: 'Ayah tafsirs in different languages',
        description: 'Tool for proofreading and suggesting the fixes for ayah tafsirs.',
        url: tafsir_proofreadings_path,
        type: 'tafsir',
        tags: [['Tafsir', 'tafsir']],
        icon: 'translation.svg',
        cta_bg: 'rgba(90, 77, 65, 0.9)'
      ),
      ToolCard.new(
        title: 'Quranic script and fonts',
        description: 'Proofread tashkeel issues in Quran script for different fonts.',
        url: '/word_text_proofreadings',
        type: 'quranic-text',
        icon: 'qaf.svg',
        tags: [['Quran Script', 'quran-script'], ['Fonts', 'fonts']],
        cta_bg: 'rgba(56, 165, 126, 0.9)'
      ),
      ToolCard.new(
        title: 'Surah Info in different languages',
        description: 'Proofread and suggest fixes for Surah information in different languages.',
        url: surah_infos_path,
        type: 'segments',
        icon: 'translation.svg',
        tags: [['Surah info', 'surah-info']],
        cta_bg: 'rgba(56, 165, 126, 0.9)'
      ),
      ToolCard.new(
        title: 'Arabic/Urdu syllable of Quran words',
        description: 'Transliteration of each word of Quran in Arabic and Urdu.',
        url: arabic_transliterations_path,
        type: 'corpus',
        tags: [['Transliteration', 'transliteration'], ['Word by Word', 'word-by-word']],
        icon: 'qaf.svg',
        cta_bg: 'rgba(56, 165, 126, 0.9)'
      ),
      ToolCard.new(
        title: 'Word by Word translation',
        description: 'Proofread and suggest fixes for word by word translations in multiple languages.',
        url: word_translations_path,
        type: 'corpus',
        tags: [['Translation', 'translation'], ['Word by Word', 'word-by-word']],
        icon: 'translation.svg',
        cta_bg: 'rgba(56, 165, 126, 0.9)'
      ),
      ToolCard.new(
        title: 'Concordance labeling of each word',
        description: 'Help us fix grammar, part of speech, and morphology data for each word of Quran.',
        url: word_concordance_labels_path,
        type: 'corpus',
        tags: [['Corpus', 'corpus'], ['Grammar', 'quranic-grammar'], ['POS', 'part-of-speech'], ['Morphology', 'quranic-morphology']],
        icon: 'tags.svg',
        cta_bg: 'rgba(56, 165, 126, 0.9)'
      ),
      ToolCard.new(
        title: 'Ayah Dependency Graphs',
        description: 'Help us preparing data for missing ayahs. Ayah Dependency Graph Tool visualizes the internal dependency structure of an ayah by presenting it as a structured graph.',
        url: morphology_dependency_graphs_path,
        type: 'corpus',
        tags: [['Corpus', 'corpus'], ['Grammar', 'quranic-grammar'], ['Morphology', 'quranic-morphology']],
        icon: 'tags.svg',
        cta_bg: 'rgba(56, 165, 126, 0.9)'
      ),
      ToolCard.new(
        title: 'Text and Font Compatibility Checker',
        description: 'Analyze Unicode values and preview Quranic text across all available fonts.',
        url: chars_info_path,
        type: 'corpus',
        tags: ['Letter Info', 'Font Preview'],
        icon: 'info.svg',
        cta_bg: 'rgba(56, 165, 126, 0.9)'
      ),
      ToolCard.new(
        title: 'Compare ayah',
        description: 'Compare ayahs',
        url: compare_ayah_path,
        type: 'ayah-reader',
        icon: 'compare.svg',
        tags: []
      ),
      ToolCard.new(
        title: 'Quran Scripts Comparison',
        description: 'Compare different Quranic script variants (Madani and Indopak) to identify inconsistencies and missing characters.',
        url: compare_words_quran_scripts_comparison_path,
        type: 'quranic-text',
        icon: 'compare.svg',
        tags: [['Quran Script', 'quran-script']],
        cta_bg: 'rgba(56, 165, 126, 0.9)'
      ),
      ToolCard.new(
        title: 'Audio Segmentations',
        description: 'This tool is used to inspect and validate the raw segmentation data of recitations by viewing detailed statistics, testing real-time word highlighting, and identifying missing or misaligned words.',
        url: segments_dashboard_path,
        type: 'segments',
        icon: 'timestamp.svg',
        tags: [['Timestamp', 'timestamp']]
      ),
      ToolCard.new(
        title: 'Compare audio',
        description: 'Compare audio recitations',
        url: '/compare-audio',
        type: 'segments',
        icon: 'timestamp.svg',
        tags: [['Timestamp', 'timestamp']]
      ),
      ToolCard.new(
        title: 'Ayah Boundary Visualizer',
        description: 'This tool visualizes ayah start and end times as timeline bars, helping to debug and refine ayah boundary data derived from raw segmentation.',
        url: '/ayah-boundaries',
        type: 'segments',
        icon: 'timeline.svg',
        tags: [['Timestamp', 'timestamp']]
      )
    ]
  end
end
