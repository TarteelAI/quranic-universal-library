# frozen_string_literal: true

module Catalog
  # The rules that infer the catalog fields no column held before: script family, rendering,
  # lifecycle status, the recommended flag, the font a layout or glyph script requires, and a
  # one-line summary. Each rule reads plain facts (Facts) and returns a value, or nil when the
  # facts do not show one. The rules draft conservatively: when signals disagree or a choice is
  # ambiguous, they return nil and leave the field to the data team. They know nothing about the
  # database; Catalog::Backfill loads the facts.
  module Inference
    # The facts of one resource. Script, font and layout facts come from the content row's meta
    # keys and its mushaf; `status`, `script_family`, `rendering` and `requires` are the values
    # the resource holds when the rule runs (a person's, or an earlier step's draft).
    #
    # text_types:    the Quran text encodings it holds or draws (`text-type`, a font's `script`)
    # font_codes:    the font names it uses (a script's `font`, a mushaf's font) or, for a font,
    #                its own names (`font-face`, `font-path`)
    # per_page:      a font with one file per mushaf page
    # svg:           a font resource that holds SVG images
    # formats:       the file types of its published files
    # recommended_by_person: true or false when a person decided the recommended flag, else nil
    # requires:      ids of the resources it has a requires-link to
    # linked_fonts:  ids of the fonts it links to that no backfill drafted
    Facts = Struct.new(:id, :type, :type_label, :name, :cardinality, :published, :status, :recommended_by_person,
                       :script_family, :rendering, :language, :text_types, :font_codes, :per_page, :svg, :tags,
                       :mushaf, :formats, :requires, :linked_fonts, keyword_init: true)
    Mushaf = Struct.new(:font, :default, :pages, :lines, keyword_init: true)

    SCRIPT_TYPES = %w[quran-script font mushaf-layout].freeze
    SUMMARY_LIMIT = 160

    module_function

    # Madani, IndoPak or other, for scripts, fonts and layouts. The text encoding decides; a
    # resource with none is decided by the fonts it names, then by its Madani or Indopak tag.
    # Signals of one kind that disagree, or a tag that contradicts the answer, give no value.
    def script_family(facts)
      return unless SCRIPT_TYPES.include?(facts.type)

      tags = agreed(facts.tags.map { |tag| tag.to_s.strip.downcase }.grep(/\A(madani|indopak)\z/))
      family = agreed(facts.text_types.map { |type| text_family(type) }) ||
               agreed(facts.font_codes.flat_map { |code| choices(code) }.map { |code| font_family(code) }) ||
               tags
      family unless tags && tags != family
    end

    def text_family(text_type)
      case text_type.to_s
      when /indopak|nastaleeq/ then 'indopak'
      when /\A(text_(uthmani|qpc_hafs|digital_khatt)|code_v\d)/ then 'madani'
      when /\Atext_(imlaei|arabic_sign)/ then 'other'
      end
    end

    def font_family(code)
      case code
      when /indopak|nastaleeq|pdms/ then 'indopak'
      when /\A(p1-)?v[124](-tajweed)?\z/, /\A(me-quran|qpc-hafs|digitalkhaa?tt?(-v\d)?)\z/ then 'madani'
      end
    end

    # How the text is drawn: glyph codes in page fonts, Unicode text in a font, images or SVG.
    def rendering(facts)
      case facts.type
      when 'quran-script' then text_rendering(facts.text_types.first)
      when 'mushaf-layout' then layout_rendering(facts)
      when 'font' then font_rendering(facts)
      end
    end

    def text_rendering(text_type)
      case text_type.to_s
      when '' then nil
      when /\Acode_v\d/ then 'glyph_page'
      when /image_url\z/ then 'image'
      else 'unicode_font'
      end
    end

    def layout_rendering(facts)
      return text_rendering(facts.text_types.first) if facts.text_types.any?

      case code(facts.font_codes.first)
      when '' then nil
      when /\Av[124](-tajweed)?\z/ then 'glyph_page'
      when 'img' then 'image'
      when 'svg' then 'svg'
      else 'unicode_font'
      end
    end

    def font_rendering(facts)
      return 'glyph_page' if facts.per_page
      return 'svg' if facts.svg

      'unicode_font' if facts.text_types.any? { |type| text_rendering(type) == 'unicode_font' }
    end

    OLD = /\(\s*old\s*\)/i
    NEW = /\(\s*(new|updated)\s*\)/i

    # [status, superseded_by_id]. A name marked "(Old)" is legacy; it is superseded when exactly
    # one other published resource of the same type and granularity has the same name without
    # the marker (or marked "(New)"), and that resource is not itself old.
    def status(facts, catalog)
      return unless facts.name.to_s.match?(OLD)

      base = base_name(facts.name)
      replacements = catalog.select do |other|
        other.id != facts.id && other.published && other.type == facts.type &&
          other.cardinality == facts.cardinality && !other.name.to_s.match?(OLD) && base_name(other.name) == base
      end
      replacements.one? ? ['superseded', replacements.first.id] : ['legacy', nil]
    end

    def base_name(name)
      name.to_s.gsub(OLD, ' ').gsub(NEW, ' ').squeeze(' ').strip.downcase
    end

    # Ids of the resources to draft as recommended. A layout is recommended when it is the only
    # published, current layout of its script family whose mushaf the content database flags as
    # the default; the font it requires is recommended with it when it requires exactly one, of
    # the same family, published and current. Which layout or font is the default is a scholarly
    # and product call, so no other evidence counts (popularity is not authority). A layout a
    # person rejected takes its font with it, and a family where a person has recommended
    # another resource gets no drafted one.
    def recommended(catalog)
      by_id = catalog.to_h { |facts| [facts.id, facts] }
      candidates = catalog.select do |facts|
        facts.type == 'mushaf-layout' && current?(facts) && facts.script_family && facts.mushaf&.default
      end

      candidates.group_by(&:script_family).flat_map do |family, layouts|
        next [] unless layouts.one? && layouts.first.recommended_by_person != false

        pair = [layouts.first.id, required_font_of(layouts.first, by_id)&.id].compact
        decided = catalog.any? do |facts|
          facts.recommended_by_person && facts.script_family == family && !pair.include?(facts.id)
        end
        decided ? [] : pair
      end
    end

    def required_font_of(layout, by_id)
      fonts = layout.requires.filter_map { |id| by_id[id] }.select { |facts| facts.type == 'font' }
      font = fonts.first if fonts.one?
      font if font && current?(font) && font.script_family == layout.script_family
    end

    def current?(facts)
      facts.published && !%w[legacy superseded].include?(facts.status)
    end

    # The id of the font a layout or a glyph script requires: the one published font whose own
    # names include the font the layout's mushaf or the script names. None when no font, or more
    # than one, has the name, or when the resource already links to another font.
    def required_font(facts, fonts)
      return unless facts.type == 'mushaf-layout' || (facts.type == 'quran-script' && facts.rendering == 'glyph_page')

      codes = facts.font_codes.flat_map { |name| choices(name) }
      matches = fonts.select do |font|
        font.published && font.font_codes.any? { |name| codes.include?(code(name)) }
      end
      return unless matches.one?

      font = matches.first
      font.id if (facts.linked_fonts - [font.id]).empty?
    end

    # A font name as both sides spell it: lower case, `_` as `-`, without a page prefix (p1-v2).
    def code(name)
      name.to_s.strip.downcase.tr('_', '-').sub(/\Ap\d+-/, '')
    end

    # A script's font can name choices ("me-quran or qpc-hafs").
    def choices(name)
      name.to_s.split(/\s+or\s+/i).map { |choice| code(choice) }.reject(&:empty?)
    end

    GRANULARITY = {
      '1_ayah' => 'ayah by ayah', '1_word' => 'word by word', 'n_ayah' => 'for one ayah or a group of ayahs',
      '1_chapter' => 'surah by surah', '1_page' => 'page by page', '1_juz' => 'juz by juz',
      '1_hizb' => 'hizb by hizb', '1_rub' => 'rub by rub', '1_manzil' => 'manzil by manzil',
      '1_ruku' => 'ruku by ruku', '1_phrase' => 'phrase by phrase'
    }.freeze

    TEXT = {
      'unicode_font' => 'Quran text in Unicode', 'glyph_page' => 'Quran text as glyph codes for page fonts',
      'image' => 'Quran text as word images'
    }.freeze

    FONT = {
      'glyph_page' => 'Glyph font with one file for each mushaf page', 'unicode_font' => 'Font for Quran text'
    }.freeze

    # File type strings end in their format (`simple.json`, `translation-text-chunk.sqlite`).
    FORMATS = {
      'json' => 'JSON', 'sqlite' => 'SQLite', 'csv' => 'CSV', 'docx' => 'DOCX', 'ttf' => 'TTF', 'otf' => 'OTF',
      'woff' => 'WOFF', 'woff2' => 'WOFF2', 'svg' => 'SVG', 'zip' => 'ZIP'
    }.freeze

    # One plain sentence from the type, language, granularity and formats, and for layouts the
    # page and line counts of the mushaf. It states only what those fields hold: nothing about
    # recitation style, qira'at or quality.
    def summary(facts)
      granularity = GRANULARITY[facts.cardinality]
      text = describe(facts, granularity)
      formats = format_list(facts.formats)
      [[text, formats].compact.join(' '), text].find { |line| line.length <= SUMMARY_LIMIT }
    end

    def describe(facts, granularity)
      language = facts.language.to_s.strip.presence
      sentence = case facts.type
                 when 'translation', 'transliteration', 'tafsir'
                   [capitalize([language, facts.type].compact.join(' ')), granularity]
                 when 'surah-info' then [capitalize("#{[language, 'introduction'].compact.join(' ')} to each surah")]
                 when 'recitation' then ['Quran recitation', granularity]
                 when 'quran-script' then [TEXT.fetch(facts.rendering, 'Quran text'), granularity]
                 when 'font' then [FONT.fetch(facts.rendering, 'Font')]
                 when 'mushaf-layout' then layout_sentence(facts.mushaf, granularity)
                 else [facts.type_label || facts.type, granularity]
                 end
      "#{sentence.compact.join(', ')}."
    end

    def layout_sentence(mushaf, granularity)
      return ['Mushaf layout', granularity] unless mushaf&.pages && mushaf.lines

      ["Mushaf layout with #{mushaf.pages} pages and #{mushaf.lines} lines on each page"]
    end

    def format_list(file_types)
      found = file_types.filter_map { |type| FORMATS.find { |suffix, _| type.to_s.downcase.end_with?(suffix) }&.last }
      names = FORMATS.values & found
      return if names.empty?

      "#{names.size > 1 ? "#{names[0..-2].join(', ')} and #{names.last}" : names.first} files."
    end

    def capitalize(text)
      text[0].upcase + text[1..]
    end

    def agreed(values)
      values = values.compact.uniq
      values.first if values.one?
    end
  end
end
