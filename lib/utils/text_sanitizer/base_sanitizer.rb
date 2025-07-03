module Utils
  module TextSanitizer
    class BaseSanitizer < Rails::Html::SafeListSanitizer
      include Utils::StrongMemoize

      REG_REF_QURAN = /(?<surah>(\d+|[ḥā'\w-]+))(\sv\.|:)*[\s\/:-]*(?<from>\d+)[\s\/:-]*(?<to>\d+)?\s?/

      attr_reader :fragment

      def html
        simple_format(fragment)
        fix_semantic_issues(fragment)
        fragment.to_html(encoding: 'UTF-8').gsub("\n", "")
      end

      def text
        fragment.to_text
      end

      def to_s
        text
      end

      protected

      def split_paragraphs(text)
        return [] if text.blank?

        text.to_str.split(/\r?\n(\r|\n)*/).select do |para|
          para.presence.present?
        end
      end

      # Remove empty tags ( except br )
      # Format text of text nodes, create paragraphs after splitting text with new line char
      def simple_format(doc, nested = false)
        if doc.text?
          process_text(doc)
        else
          doc.children.each do |node|
            next if node.name == 'br'

            if node.text?
              process_text(node)
            else
              if node.text.strip.blank?
                node.remove
              else
                if node.name == 'div'
                  if node.children.size == 1 && node.children.first.text?
                    node.name = 'p'
                    process_text(node)
                  else
                    node.children.each do |sub_child|
                      simple_format sub_child, true
                    end
                  end
                end

                set_content_lang(node)
              end
            end
          end
        end
      end

      def fix_semantic_issues(doc)
        # Select and remove parent <p> elements containing nested <p> elements
        doc.css('p p').each do |nested_p|
          parent_p = nested_p.parent
          parent_p.children = nested_p
        end

        doc.search("p").each do |p|
          p.remove if p.content.strip.blank?
        end
      end

      def process_text(node)
        if node.text.strip.blank?
          node.remove
        else
          replace_linebreak_with_paragraphs(node) if split_text_into_para
        end
      end

      def replace_linebreak_with_paragraphs(node)
        paragraphs = split_paragraphs(node.text.strip).compact_blank
        return if paragraphs.length <= 1

        text = paragraphs.map do |paragraph|
          p = node.document.create_element('p', paragraph.strip)
          set_content_lang(p)
        end

        with_para = Nokogiri::XML::NodeSet.new(node.document, text).to_s
        with_para.set_attribute('class', node.get_attribute('class')) if node.get_attribute('class').present?
        node.replace(with_para)
      end

      def set_content_lang(node)
        if node.lang.blank? && (content_lang = detect_content_lang(node.text))
          if content_lang.present?
            node.set_attribute('lang', content_lang)
            node.set_attribute('class', "#{content_lang} #{node.get_attribute('class')}")
          end
        end

        node
      end

      def detect_content_lang(text)
        text = text.gsub(/[\p{P}\p{S}]/, '')
        detectors = lang_detector
        lang = nil

        detectors.each do |detector|
          break if lang
          lang = accept_language?(detector.find_top_n_most_freq_langs(text.to_s.remove_diacritics, 1).map do |part|
            part.language.to_s
          end.first)

          lang ||= accept_language?(detector.find_top_n_most_freq_langs(text.to_s.strip, 1).map do |part|
            part.language.to_s
          end.first)

          lang ||= accept_language?(detector.find_language(text.to_s.strip)&.language)
        end

        lang || resource_language
      rescue Exception => e
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

          [
            CLD3::NNetLanguageIdentifier.new,
            CLD3::NNetLanguageIdentifier.new(10, 100),
          ]
        end
      end

      def accept_language?(lang)
        return false if lang.blank?

        language_mapping = {
          'ar' => ['ar', 'en'],
          'en' => ['en', 'ar'],
          'ur' => ['en', 'ar', 'ur']
        }

        accepted_language = language_mapping[resource_language] || []
        lang if (accepted_language.blank? || accepted_language.include?(lang))
      end
    end
  end
end