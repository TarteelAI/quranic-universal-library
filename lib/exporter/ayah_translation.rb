module Exporter
  class AyahTranslation
    HARD_CODED_FOOTNOTES = {
      'sg' => 'singular',
      'pl' => 'plural',
      'dl' => 'dual'
    }

    def export_inline_footnote(translation)
      text = translation&.text.to_s

      if text.blank?
        return {
          t: []
        }
      end

      doc = Nokogiri::HTML::DocumentFragment.parse(text)

      doc.search("a sup, sup").each do |node|
        t = node.text.strip.presence.to_s
        footnote_id = node.attr('foot_note')

        if footnote = HARD_CODED_FOOTNOTES[t]
          node.content = "[[#{footnote}]]"
        elsif footnote_id && (text = get_footnote_text(footnote_id))
          node.content = "[[#{text}]]"
        else
          node.remove
        end
      end

      { t: doc.text }
    end

    def export_chunks(translation)
      text = translation&.text.to_s

      if text.blank?
        return {
          t: []
        }
      end

      doc = Nokogiri::HTML::DocumentFragment.parse(text)
      export_translation_chunks(doc)
    end

    protected

    def export_translation_chunks(doc)
      footnotes_refs = {}
      footnotes = {}
      foot_note_counter = 1
      translation_chunks = []

      doc.css('sup').each do |sup|
        if HARD_CODED_FOOTNOTES[sup.text.strip]
          footnotes[sup.text.strip] = HARD_CODED_FOOTNOTES[sup.text.strip]
        else
          id = sup.attr('foot_note')

          if id && text = get_footnote_text(id)
            footnotes[foot_note_counter.to_s] = text
            footnotes_refs[id] = foot_note_counter.to_s
            foot_note_counter += 1
          end
        end
      end

      process_node = ->(node) do
        case node.name
        when 'text'
          node.text if node.text.strip.present?
        when 'span'
          text = node.children.map { |child| process_node.call(child) }.compact.join

          if node.attr('class') == 'h'
            { type: 'b', text: text } if text.present?
          else
            text
          end
        when 'i', 'b', 'small'
          text = node.children.map { |child| process_node.call(child) }.compact.join
          { type: node.name, text: text } if text.present?
        when 'sup'
          if node.attr('foot_note').present?
            id = node.attr('foot_note')
            { type: 'f', text: footnotes_refs[id] } if id && footnotes_refs[id]
          else
            key = node.text.strip
            if HARD_CODED_FOOTNOTES.key?(key)
              { type: 'f', text: key }
            end
          end
        else
          node.children.map { |child| process_node.call(child) }.compact
        end
      end

      doc.children.each do |child|
        result = process_node.call(child)

        if result.is_a?(Array)
          translation_chunks.concat(result)
        elsif result.present?
          translation_chunks << result
        end
      end

      result = {
        t: translation_chunks,
        f: footnotes
      }
      result.delete(:f) if result[:f].blank?

      result
    end

    def get_footnote_text(id)
      footnote = FootNote.where(id: id).first
      return if footnote.blank? || footnote.text.blank?

      # Some footnote has HTML tags, strip those tags
      text = Nokogiri::HTML::DocumentFragment.parse(footnote.text).text
      text.tr(" ", ' ')
    end
  end
end