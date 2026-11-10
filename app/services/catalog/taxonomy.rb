# frozen_string_literal: true

module Catalog
  # The catalog vocabulary: the 14 resource types, their labels and descriptions, and the
  # category each belongs to. This file is the one source for that copy. Pages receive it as
  # props; the React side holds no copy of it.
  module Taxonomy
    Category = Data.define(:key, :label)
    Type = Data.define(:key, :label, :title, :summary, :description, :category)

    CATEGORIES = [
      Category.new(key: 'audio', label: 'Audio'),
      Category.new(key: 'layout', label: 'Mushaf layouts'),
      Category.new(key: 'script', label: 'Script and fonts'),
      Category.new(key: 'translation', label: 'Translation'),
      Category.new(key: 'tafsir', label: 'Tafsir and commentary'),
      Category.new(key: 'linguistics', label: 'Linguistics'),
      Category.new(key: 'topics', label: 'Topics and themes'),
      Category.new(key: 'metadata', label: 'Metadata')
    ].index_by(&:key).freeze

    TYPES = [
      Type.new(
        key: 'recitation', label: 'Recitation', title: 'Recitations', category: CATEGORIES.fetch('audio'),
        summary: 'Surah and ayah audio, with timestamps for each ayah and word.',
        description: 'Audio files of full Quran recitations, surah by surah or ayah by ayah. Many recitations ' \
                     'have segment data: the start and end time of each ayah and each word. Use the segments ' \
                     'to highlight the text while the audio plays.'
      ),
      Type.new(
        key: 'mushaf-layout', label: 'Mushaf layout', title: 'Mushaf layouts', category: CATEGORIES.fetch('layout'),
        summary: 'Page, line and word positions of printed mushaf editions.',
        description: 'Page, line and word positions of printed mushaf editions. Use a layout to show Quran ' \
                     'pages as they look in print. Use it with the matching font and script.'
      ),
      Type.new(
        key: 'quran-script', label: 'Quran script', title: 'Quran scripts', category: CATEGORIES.fetch('script'),
        summary: 'The Quran text in Unicode, ayah by ayah and word by word.',
        description: 'The Quran text in Unicode, ayah by ayah and word by word. Scripts include Madani ' \
                     '(Uthmani), IndoPak and simple text. Some scripts have tajweed marks.'
      ),
      Type.new(
        key: 'font', label: 'Font', title: 'Fonts', category: CATEGORIES.fetch('script'),
        summary: 'Quran fonts, glyph fonts for each mushaf page, and surah name fonts.',
        description: 'Fonts for Quran text. There are Unicode fonts, glyph fonts with one file for each ' \
                     'mushaf page, and fonts for surah names and surah headers.'
      ),
      Type.new(
        key: 'translation', label: 'Translation', title: 'Translations', category: CATEGORIES.fetch('translation'),
        summary: 'Ayah by ayah and word by word translations in many languages.',
        description: 'Translations of the Quran in many languages. Each translation is ayah by ayah or ' \
                     'word by word.'
      ),
      Type.new(
        key: 'transliteration', label: 'Transliteration', title: 'Transliterations',
        category: CATEGORIES.fetch('translation'),
        summary: 'The Arabic text in Latin letters, to help people read it aloud.',
        description: 'The Arabic text written in Latin letters, to help people read it aloud. ' \
                     'Transliterations are ayah by ayah or word by word.'
      ),
      Type.new(
        key: 'tafsir', label: 'Tafsir', title: 'Tafsirs', category: CATEGORIES.fetch('tafsir'),
        summary: 'Short and detailed commentaries, for one ayah or a group of ayahs.',
        description: 'Commentaries on the Quran in many languages. Some are short and some are detailed. ' \
                     'Each tafsir entry is for one ayah or for a group of ayahs.'
      ),
      Type.new(
        key: 'surah-info', label: 'Surah info', title: 'Surah info', category: CATEGORIES.fetch('tafsir'),
        summary: 'An introduction to each surah.',
        description: 'An introduction to each surah: when it was revealed, its main themes and its context.'
      ),
      Type.new(
        key: 'morphology', label: 'Morphology', title: 'Morphology and grammar',
        category: CATEGORIES.fetch('linguistics'),
        summary: 'Roots, lemmas, stems, grammar and dependency graphs.',
        description: 'Language data for each word of the Quran: roots, lemmas, stems, grammar terms and ' \
                     'dependency graphs.'
      ),
      Type.new(
        key: 'mutashabihat', label: 'Mutashabihat', title: 'Mutashabihat', category: CATEGORIES.fetch('topics'),
        summary: 'Similar phrases that are easy to confuse when you memorise.',
        description: 'Phrases that occur in more than one place in the Quran and are easy to confuse. ' \
                     'Use this data to help people memorise.'
      ),
      Type.new(
        key: 'similar-ayah', label: 'Similar ayah', title: 'Similar ayahs', category: CATEGORIES.fetch('topics'),
        summary: 'Ayahs with similar wording, with a match score.',
        description: 'Pairs of ayahs with similar wording. Each pair has a score that shows how closely ' \
                     'the ayahs match.'
      ),
      Type.new(
        key: 'ayah-topics', label: 'Ayah topics', title: 'Ayah topics', category: CATEGORIES.fetch('topics'),
        summary: 'Topics and concepts, with the ayahs that mention them.',
        description: 'Topics and concepts, with the ayahs that mention each one.'
      ),
      Type.new(
        key: 'ayah-theme', label: 'Ayah theme', title: 'Ayah themes', category: CATEGORIES.fetch('topics'),
        summary: 'Themes for groups of consecutive ayahs.',
        description: 'Themes for groups of consecutive ayahs. Each theme covers a range of ayahs.'
      ),
      Type.new(
        key: 'quran-metadata', label: 'Quran metadata', title: 'Quran metadata',
        category: CATEGORIES.fetch('metadata'),
        summary: 'Surah, ayah and word data, and juz, hizb, rub, manzil, ruku and sajda boundaries.',
        description: 'The structure of the Quran: surahs, ayahs and words, and where each juz, hizb, rub, ' \
                     'manzil, ruku and sajda starts and ends.'
      )
    ].index_by(&:key).freeze

    # A value of one of the search vocabularies below, with its label.
    Option = Data.define(:key, :label)

    # The formats a file can have. File type strings (about two dozen, several of them variants
    # of JSON and SQLite) map onto these in .format_for.
    FORMATS = [
      Option.new(key: 'json', label: 'JSON'),
      Option.new(key: 'sqlite', label: 'SQLite'),
      Option.new(key: 'csv', label: 'CSV'),
      Option.new(key: 'docx', label: 'Word document'),
      Option.new(key: 'font', label: 'Font file'),
      Option.new(key: 'svg', label: 'SVG'),
      Option.new(key: 'image', label: 'Images'),
      Option.new(key: 'other', label: 'Other')
    ].freeze

    FONT_FILE_TYPES = ['ttf', 'otf', 'woff', 'woff2', 'font pack'].freeze

    SCRIPT_FAMILIES = [
      Option.new(key: 'madani', label: 'Madani'),
      Option.new(key: 'indopak', label: 'IndoPak'),
      Option.new(key: 'other', label: 'Other scripts')
    ].freeze

    STATUSES = [
      Option.new(key: 'stable', label: 'Stable'),
      Option.new(key: 'beta', label: 'Beta'),
      Option.new(key: 'legacy', label: 'Legacy'),
      Option.new(key: 'superseded', label: 'Superseded')
    ].freeze

    RENDERINGS = [
      Option.new(key: 'unicode_font', label: 'Unicode text and font'),
      Option.new(key: 'glyph_page', label: 'Glyph font for each page'),
      Option.new(key: 'image', label: 'Images'),
      Option.new(key: 'svg', label: 'SVG')
    ].freeze

    # How to choose among the resources of a type, for the "Which one should I pick?" block of a
    # type page. A type without its own text gets PICK_DEFAULT.
    PICKS = {
      'mushaf-layout' => 'Use the layout of the printed mushaf that your readers know. The Font column of the ' \
                         'table names the font that a layout needs. A glyph layout uses one font file for each ' \
                         'page and looks the same as the print.',
      'quran-script' => 'Use a script in the same script family as your font. Madani scripts are for most ' \
                        'readers. IndoPak scripts are for readers in South Asia. A glyph script needs its own ' \
                        'font, which the table names.',
      'font' => 'Use the font that your layout or script needs. The tables on the layout and script pages ' \
                'name the font for each one.'
    }.freeze
    PICK_DEFAULT = 'Use a current resource. Older versions stay available for apps that already use them.'

    # The columns of the comparison table on a type page, and the types that have one.
    COMPARISON_COLUMNS = [
      Option.new(key: 'script_family', label: 'Script family'),
      Option.new(key: 'pages', label: 'Pages'),
      Option.new(key: 'lines_per_page', label: 'Lines per page'),
      Option.new(key: 'rendering', label: 'Rendering'),
      Option.new(key: 'font', label: 'Font'),
      Option.new(key: 'status', label: 'Status')
    ].index_by(&:key).freeze
    COMPARISONS = {
      'mushaf-layout' => %w[script_family pages lines_per_page rendering font status],
      'quran-script' => %w[script_family rendering font status],
      'font' => %w[script_family rendering status]
    }.freeze

    # Granularity is the resource's cardinality type.
    GRANULARITIES = [
      Option.new(key: '1_word', label: 'Word by word'),
      Option.new(key: '1_phrase', label: 'Phrase'),
      Option.new(key: '1_ayah', label: 'Ayah by ayah'),
      Option.new(key: 'n_ayah', label: 'Multiple ayahs'),
      Option.new(key: '1_ruku', label: 'Ruku'),
      Option.new(key: '1_page', label: 'Page by page'),
      Option.new(key: '1_chapter', label: 'Surah by surah'),
      Option.new(key: '1_rub', label: 'Rub'),
      Option.new(key: '1_hizb', label: 'Hizb'),
      Option.new(key: '1_juz', label: 'Juz'),
      Option.new(key: '1_manzil', label: 'Manzil'),
      Option.new(key: '1_sajda', label: 'Sajda'),
      Option.new(key: 'quran', label: 'Whole Quran')
    ].freeze

    SORTS = [
      Option.new(key: 'popular', label: 'Most downloaded'),
      Option.new(key: 'name', label: 'Name'),
      Option.new(key: 'updated', label: 'Recently updated')
    ].freeze

    def self.types
      TYPES.values
    end

    def self.type(key)
      TYPES[key.to_s]
    end

    def self.formats = FORMATS
    def self.script_families = SCRIPT_FAMILIES
    def self.statuses = STATUSES
    def self.granularities = GRANULARITIES
    def self.sorts = SORTS
    def self.renderings = RENDERINGS

    def self.pick(type)
      PICKS.fetch(type.key, PICK_DEFAULT)
    end

    def self.comparison_columns(type)
      COMPARISONS.fetch(type.key, []).map { |key| COMPARISON_COLUMNS.fetch(key) }
    end

    def self.label(options, key)
      options.find { |option| option.key == key }&.label
    end

    def self.format_for(file_type)
      type = file_type.to_s.strip.downcase
      return 'json' if type.end_with?('json')
      return 'sqlite' if type.end_with?('sqlite')
      return 'font' if FONT_FILE_TYPES.include?(type)
      return 'image' if type == 'images'

      FORMATS.any? { |format| format.key == type } ? type : 'other'
    end
  end
end
