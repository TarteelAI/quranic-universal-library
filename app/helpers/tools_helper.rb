module ToolsHelper
  def developer_tools
    tools = [
      ToolCard.new(
        title: 'Mushaf layouts',
        description: 'Build and proofread Mushaf page layouts: the words on each line and how each line is aligned (15 lines, 16 lines, v1, v2 etc).',
        url: '/mushaf_layouts',
        type: 'mushaf-layout',
        icon: 'layout.svg',
        tags: [['Mushaf Layout', 'mushaf-layout']]
      ),
      ToolCard.new(
        title: 'Tajweed rules',
        description: 'Proofread and fix the tajweed rules marked on the letters of the Quran text.',
        url: tajweed_words_path,
        type: 'tajweed-tool',
        icon: 'tajweed.svg',
        tags: [['Tajweed', 'tajweed']]
      ),
      ToolCard.new(
        title: 'Mutashabihat',
        description: 'Find and review phrases that repeat across ayahs, often with a small difference that is easy to mix up while memorizing.',
        url: '/morphology_phrases',
        type: 'mutashabihat',
        icon: 'mutashabihat.svg',
        cta_bg: 'rgba(56, 152, 173, 0.9)',
        tags: [['Mutashabihat', 'mutashabihat']]
      ),
      ToolCard.new(
        title: 'Surah audio segments',
        description: 'Create and fix the timestamp of each word in surah by surah recitations.',
        url: '/surah_audio_files',
        type: 'segments',
        tags: [['Recitation', 'recitation'], ['Surah by Surah', 'surah-by-surah'], ['Timestamp', 'timestamp']],
        icon: 'timestamp.svg',
        cta_bg: 'rgba(56, 165, 126, 0.9)'
      ),
      ToolCard.new(
        title: 'Ayah audio segments',
        description: 'Create and fix the timestamp of each word in ayah by ayah recitations.',
        url: '/ayah_audio_files',
        type: 'segments',
        tags: [['Recitation', 'recitation'], ['Ayah by Ayah', 'ayah-by-ayah'], ['Timestamp', 'timestamp']],
        icon: 'timestamp.svg',
        cta_bg: 'rgba(56, 165, 126, 0.9)'
      ),
      ToolCard.new(
        title: 'Ayah translations',
        description: 'Proofread and suggest fixes for ayah translations in many languages.',
        url: translations_path,
        type: 'translation',
        tags: [['Translation', 'translation']],
        icon: 'translation.svg',
        cta_bg: 'rgba(90, 77, 65, 0.9)'
      ),
      ToolCard.new(
        title: 'Ayah transliterations',
        description: 'Proofread and suggest fixes for ayah transliterations.',
        url: transliterations_path,
        type: 'transliteration',
        tags: [['Transliteration', 'transliteration']],
        icon: 'translation.svg',
        cta_bg: 'rgba(90, 77, 65, 0.9)'
      ),
      ToolCard.new(
        title: 'Tafsirs',
        description: 'Proofread and suggest fixes for tafsirs in many languages, and for the ayahs each tafsir covers.',
        url: tafsirs_path,
        type: 'tafsir',
        tags: [['Tafsir', 'tafsir']],
        icon: 'translation.svg',
        cta_bg: 'rgba(90, 77, 65, 0.9)'
      ),
      ToolCard.new(
        title: 'Quran scripts and fonts',
        description: 'Proofread each Quran script in its fonts and find missing or wrong tashkeel.',
        url: '/word_texts',
        type: 'quranic-text',
        icon: 'qaf.svg',
        tags: [['Quran Script', 'quran-script'], ['Fonts', 'fonts']],
        cta_bg: 'rgba(56, 165, 126, 0.9)'
      ),
      ToolCard.new(
        title: 'Ayah topics',
        description: 'Proofread and suggest fixes for topics and the ayahs linked to each topic.',
        url: topics_path,
        type: 'topic',
        icon: 'tags.svg',
        tags: [['Topics', 'ayah-topics']],
        cta_bg: 'rgba(56, 165, 126, 0.9)'
      ),
      ToolCard.new(
        title: 'Ayah themes',
        description: 'Proofread and suggest fixes for the theme and keywords of each group of ayahs.',
        url: themes_path,
        type: 'theme',
        icon: 'list.svg',
        tags: [['Themes', 'ayah-theme']],
        cta_bg: 'rgba(56, 165, 126, 0.9)'
      ),
      ToolCard.new(
        title: 'Similar ayahs',
        description: 'Proofread and suggest fixes for the ayahs that share a phrase or most of their words with each ayah.',
        url: similar_ayahs_path,
        type: 'mutashabihat',
        icon: 'mutashabihat.svg',
        tags: [['Similar Ayah', 'similar-ayah']],
        cta_bg: 'rgba(56, 165, 126, 0.9)'
      ),
      ToolCard.new(
        title: 'Surah info',
        description: 'Proofread and suggest fixes for Surah introductions in many languages.',
        url: surah_infos_path,
        type: 'segments',
        icon: 'translation.svg',
        tags: [['Surah info', 'surah-info']],
        cta_bg: 'rgba(56, 165, 126, 0.9)'
      ),
      ToolCard.new(
        title: 'Word syllables in Arabic and Urdu',
        description: 'Proofread and fix how each Quran word is split into syllables, written in Arabic and Urdu script.',
        url: arabic_transliterations_path,
        type: 'corpus',
        tags: [['Transliteration', 'transliteration'], ['Word by Word', 'word-by-word']],
        icon: 'qaf.svg',
        cta_bg: 'rgba(56, 165, 126, 0.9)'
      ),
      ToolCard.new(
        title: 'Word by word translations',
        description: 'Proofread and suggest fixes for the meaning of each Quran word, in many languages.',
        url: select_resource_word_translations_path,
        type: 'corpus',
        tags: [['Translation', 'translation'], ['Word by Word', 'word-by-word']],
        icon: 'translation.svg',
        cta_bg: 'rgba(56, 165, 126, 0.9)'
      ),
      ToolCard.new(
        title: 'Word by word transliterations',
        description: 'Proofread and suggest fixes for the transliteration of each Quran word.',
        url: word_transliterations_path,
        type: 'corpus',
        tags: [['Transliteration', 'transliteration'], ['Word by Word', 'word-by-word']],
        icon: 'translation.svg',
        cta_bg: 'rgba(56, 165, 126, 0.9)'
      ),
      ToolCard.new(
        title: 'Word roots, stems and lemmas',
        description: 'Proofread and suggest fixes for the root, stem and lemma of each Quran word, and their meanings.',
        url: word_roots_path,
        type: 'corpus',
        tags: [['Morphology', 'quranic-morphology']],
        icon: 'qaf.svg',
        cta_bg: 'rgba(56, 165, 126, 0.9)'
      ),
      ToolCard.new(
        title: 'Word grammar and morphology',
        description: 'Review the grammar, part of speech and morphology of each Quran word, and report what is wrong.',
        url: word_concordance_labels_path,
        type: 'corpus',
        tags: [['Corpus', 'corpus'], ['Grammar', 'quranic-grammar'], ['POS', 'part-of-speech'], ['Morphology', 'quranic-morphology']],
        icon: 'tags.svg',
        cta_bg: 'rgba(56, 165, 126, 0.9)'
      ),
      ToolCard.new(
        title: 'Ayah dependency graphs',
        description: 'View and edit the grammatical structure of each ayah as a graph, and build graphs for ayahs that have none yet.',
        url: morphology_dependency_graphs_path,
        type: 'corpus',
        tags: [['Corpus', 'corpus'], ['Grammar', 'quranic-grammar'], ['Morphology', 'quranic-morphology']],
        icon: 'tags.svg',
        cta_bg: 'rgba(56, 165, 126, 0.9)'
      ),
      ToolCard.new(
        title: 'Unicode and font checker',
        description: 'See the Unicode of each character in a text, and preview the text in every Quran font.',
        url: chars_info_path,
        type: 'corpus',
        tags: ['Letter Info', 'Font Preview'],
        icon: 'info.svg',
        cta_bg: 'rgba(56, 165, 126, 0.9)'
      ),
      ToolCard.new(
        title: 'Compare ayahs',
        description: 'Open several ayahs side by side to compare their text, translations and more.',
        url: compare_ayah_path,
        type: 'ayah-reader',
        icon: 'compare.svg',
        tags: []
      ),
      ToolCard.new(
        title: 'Compare Quran scripts',
        description: 'Compare the Madani and Indopak scripts word by word to find missing or different characters.',
        url: compare_words_quran_scripts_comparison_path,
        type: 'quranic-text',
        icon: 'compare.svg',
        tags: [['Quran Script', 'quran-script']],
        cta_bg: 'rgba(56, 165, 126, 0.9)'
      ),
      ToolCard.new(
        title: 'Compare audio',
        description: 'Play two audio files side by side and compare their length, waveform and pauses.',
        url: '/compare-audio',
        type: 'segments',
        icon: 'timestamp.svg',
        tags: [['Timestamp', 'timestamp']]
      ),
      ToolCard.new(
        title: 'Compare fonts',
        description: 'Compare two builds of a font to see what changed before shipping the update.',
        url: '/compare-font',
        type: 'quranic-text',
        icon: 'compare.svg',
        tags: [['Fonts', 'fonts'], 'Compare'],
        cta_bg: 'rgba(56, 165, 126, 0.9)'
      ),
      ToolCard.new(
        title: 'Ayah audio cutter',
        description: 'Cut ayah by ayah audio out of a full surah recitation.',
        url: '/gapless-ayah-extractor',
        type: 'segments',
        icon: 'timestamp.svg',
        tags: [['Recitation', 'recitation'], ['Surah by Surah', 'surah-by-surah']]
      )
    ]

    tools + internal_developer_tools
  end

  def internal_developer_tools
    return [] unless qul_scripts_available?

    [
      ToolCard.new(
        title: 'Segment pipeline',
        description: 'Generate and check the word timestamps of any recitation, and follow each run.',
        url: segment_pipeline_root_path,
        type: 'segments',
        icon: 'timestamp.svg',
        tags: [['Recitation', 'recitation'], ['Timestamp', 'timestamp']]
      ),

       ToolCard.new(
        title: 'Add reciter audio',
        description: 'Import and check the recordings of a new reciter, one surah at a time.',
        url: audio_repair_ingests_path,
        type: 'segments',
        icon: 'timestamp.svg',
        tags: [['Recitation', 'recitation'], ['Surah by Surah', 'surah-by-surah']]
      )
    ]
  end
end
