require 'mini_magick'

module OpenGraph
  class ImageGenerator
    WIDTH = 1200
    HEIGHT = 630

    def initialize(locale:)
      @locale = locale.to_s
    end

    def render_ayah(verse, output_path)
      chapter = verse.chapter
      title = "#{chapter_name(chapter)} • #{verse.verse_number}"
      text = ayah_primary_text(verse)

      render_base(
        output_path: output_path,
        title: title,
        body: trimmed(text, max_chars: rtl? ? 320 : 420),
        subtitle: reference_label(chapter, verse.verse_number)
      )
    end

    def render_surah(chapter, output_path)
      title = chapter_name(chapter)
      subtitle = surah_label(chapter)

      render_base(
        output_path: output_path,
        title: title,
        body: '',
        subtitle: subtitle
      )
    end

    def render_word(word, output_path)
      verse = word.verse
      chapter = verse.chapter
      title = word.text_uthmani.to_s
      subtitle = reference_label(chapter, verse.verse_number, word.position)
      body = word_secondary_text(word)

      render_base(
        output_path: output_path,
        title: title,
        body: trimmed(body, max_chars: 180),
        subtitle: subtitle
      )
    end

    private

    def render_base(output_path:, title:, body:, subtitle:)
      footer_h = 110
      body_top = 96
      MiniMagick::Tool::Convert.new do |c|
        c.size "#{WIDTH}x#{HEIGHT}"
        c << "xc:#0b1020"
        c << output_path
      end

      image = MiniMagick::Image.open(output_path)

      image.combine_options do |c|
        c.fill '#ffffff'
        c.font primary_font_path
        c.pointsize rtl? ? 64 : 60
        c.gravity rtl? ? 'NorthEast' : 'NorthWest'
        c.direction(rtl? ? 'RightToLeft' : 'LeftToRight')
        c.annotate "+80+72", title.to_s
      end

      if subtitle.to_s.present?
        image.combine_options do |c|
          c.fill '#cbd5e1'
          c.font secondary_font_path
          c.pointsize 28
          c.gravity rtl? ? 'NorthEast' : 'NorthWest'
          c.direction(rtl? ? 'RightToLeft' : 'LeftToRight')
          c.annotate "+80+126", subtitle.to_s
        end
      end

      if body.to_s.present?
        wrapped = wrap_text(body.to_s, max_chars_per_line: rtl? ? 26 : 34, max_lines: 5)
        image.combine_options do |c|
          c.fill '#e2e8f0'
          c.font secondary_font_path
          c.pointsize rtl? ? 44 : 42
          c.gravity rtl? ? 'NorthEast' : 'NorthWest'
          c.direction(rtl? ? 'RightToLeft' : 'LeftToRight')
          c.interline_spacing 10
          c.annotate "+80+#{body_top + 92}", wrapped
        end
      end

      image.combine_options do |c|
        c.fill '#0a0f1f'
        c.draw "rectangle 0,#{HEIGHT - footer_h} #{WIDTH},#{HEIGHT}"
      end

      qul_logo_path = Rails.root.join('app', 'assets', 'images', 'logo.svg').to_s
      tarteel_logo_path = Rails.root.join('app', 'assets', 'images', 'tarteel-logo.png').to_s

      begin
        qul = MiniMagick::Image.open(qul_logo_path)
        qul.resize '48x48'
        image = image.composite(qul) do |c|
          c.gravity 'SouthWest'
          c.geometry '+80+28'
        end
      rescue StandardError
      end

      tarteel = MiniMagick::Image.open(tarteel_logo_path)
      tarteel.resize '140x'
      image = image.composite(tarteel) do |c|
        c.gravity 'SouthEast'
        c.geometry '+80+28'
      end

      image.combine_options do |c|
        c.font secondary_font_path
        c.fill '#94a3b8'
        c.pointsize 22
        c.gravity 'South'
        c.annotate '+0+40', footer_text
      end

      image.format 'png'
      image.write output_path
    end

    def rtl?
      @locale.to_s.downcase.start_with?('ar', 'fa', 'ur')
    end

    def footer_text
      'Quranic Universal Library • Tarteel'
    end

    def primary_font_path
      Rails.root.join('app', 'assets', 'fonts', 'OpenSauceOne-Regular.ttf').to_s
    end

    def secondary_font_path
      Rails.root.join('app', 'assets', 'fonts', 'OpenSauceOne-Regular.ttf').to_s
    end

    def chapter_name(chapter)
      return chapter.name_arabic.to_s if rtl?

      lang = Language.find_by(iso_code: @locale)
      if lang
        name = chapter.translated_names.find_by(language_id: lang.id)&.name
        return name.to_s if name.present?
      end

      chapter.name_simple.to_s
    end

    def surah_label(chapter)
      if rtl?
        "سورة #{chapter.chapter_number}"
      else
        "Surah #{chapter.chapter_number}"
      end
    end

    def reference_label(chapter, ayah_number, word_position = nil)
      if word_position
        if rtl?
          "#{chapter_name(chapter)} • آية #{ayah_number} • كلمة #{word_position}"
        else
          "#{chapter_name(chapter)} • Ayah #{ayah_number} • Word #{word_position}"
        end
      else
        if rtl?
          "#{chapter_name(chapter)} • آية #{ayah_number}"
        else
          "#{chapter_name(chapter)} • Ayah #{ayah_number}"
        end
      end
    end

    def ayah_primary_text(verse)
      return verse.text_qpc_hafs.to_s if rtl?

      lang = Language.find_by(iso_code: @locale) || Language.default
      tr = verse.translations.where(language_id: lang.id).order(:priority, :id).first
      tr&.text.to_s.presence || verse.text_qpc_hafs.to_s
    end

    def word_secondary_text(word)
      return '' if rtl?

      lang = Language.find_by(iso_code: @locale) || Language.default
      wt = WordTranslation.where(word_id: word.id, language_id: lang.id).order(:priority, :id).first
      wt&.text.to_s
    end

    def trimmed(text, max_chars:)
      t = text.to_s.strip
      return '' if t.blank?
      return t if t.length <= max_chars

      sliced = t[0, max_chars].to_s
      "#{sliced}…"
    end

    def wrap_text(text, max_chars_per_line:, max_lines:)
      t = text.to_s.strip
      return '' if t.blank?

      words = t.split(/\s+/)
      lines = []
      current = +''

      words.each do |w|
        candidate = current.blank? ? w : "#{current} #{w}"
        if candidate.length <= max_chars_per_line
          current = candidate
        else
          lines << current
          current = w
        end
        break if lines.size >= max_lines
      end

      if lines.size < max_lines && current.present?
        lines << current
      end

      lines = lines.first(max_lines)
      if words.join(' ').length > lines.join(' ').length
        last = lines.pop.to_s
        last = last[0, [last.length - 1, 0].max]
        lines << "#{last}…"
      end

      lines.join("\n")
    end
  end
end

