module Text
  class BaseSanitizer < Rails::Html::SafeListSanitizer
    include Utils::StrongMemoize

    # REG_REF_QURAN = /(?<surah>\d+)[\s\/:-]*(?<from>\d+)[\s\/:-]*(?<to>\d+)?\s?/
    REG_REF_QURAN = /(?<surah>(\d+|[ḥā'\w-]+))(\sv\.|:)*[\s\/:-]*(?<from>\d+)[\s\/:-]*(?<to>\d+)?\s?/
    REG_REF_HASHTAG = /#[\w]+\s?/

    attr_reader :fragment

    def html
      simple_format
      add_references fragment.to_html(encoding: 'UTF-8')
    end

    def text
      fragment.to_text
    end

    def to_s
      text
    end

    protected

    # return sanitize result as Loofah fragment instead of string
    def properly_encode(fragment, options)
      fragment
    end

    def add_references(text)
      text = add_quran_ref(text)
      add_hashtag_ref(text)
    end

    def add_quran_ref(text)
      text.gsub(REG_REF_QURAN) do |matched_text|
        match = Regexp.last_match
        surah = match[:surah]
        from = match[:from]
        to = match[:to] || from

        if surah == 'Quran' && Utils::Quran.valid_range?(from, to, to)
          " <quran ref=/#{from}/#{to}-#{to}>#{matched_text.strip}</quran> "
        else
          surah = NavigationSearchRecord.for_surah.search(surah)

          if surah && Utils::Quran.valid_range?(surah.id, from, to)
            " <quran ref=/#{surah.id}/#{from}-#{to}>#{matched_text.strip}</quran> "
          else
            matched_text
          end
        end
      end
    end

    def add_hashtag_ref(text)
      text.gsub(REG_REF_HASHTAG) do |matched_text|
        "<tag>#{matched_text.strip}</tag> "
      end
    end

    def split_paragraphs(text)
      return [] if text.blank?

      text.to_str.split(/\r?\n(\r|\n)*/).select do |para|
        para.presence.present?
      end
    end

    # Remove empty tags ( except br )
    # Format text of text nodes, create paragraphs after splitting text with new line char
    def simple_format
      fragment.children.each do |child|
        next if child.name == 'br'

        if child.text?
          convert_text_to_paragraphs(child)
        else
          if child.text.blank?
            child.remove
          else
            if child.name == 'div' && child.children.size == 1 && child.children.first.text?
              child.name = 'p'
            end

            set_content_lang(child)
          end
        end
      end
    end

    def convert_text_to_paragraphs(node)
      paragraphs = split_paragraphs(node.text).compact_blank

      text = paragraphs.map do |paragraph|
        p = node.document.create_element('p', paragraph.strip)
        set_content_lang(p)
      end

      node.replace(Nokogiri::XML::NodeSet.new(node.document, text).to_s)
    end

    def set_content_lang(node)
      if node.lang.blank? && (content_lang = detect_content_lang(node.text))
        node.set_attribute('lang', content_lang)
      end

      node
    end

    def detect_content_lang(text)
      lang_detector.find_top_n_most_freq_langs(text.to_s.remove_dialectic, 1).map do |part|
        part.language.to_s
      end.first
    rescue Exceptiuon => e
      puts e.message
    end

    def lang_detector
      strong_memoize :lang_detector do
        begin
          require 'cld3'
        rescue Exception => e
          puts "Can't load cld3..error #{e.message}"
          return false
        end

        CLD3::NNetLanguageIdentifier.new
      end
    end
  end
end