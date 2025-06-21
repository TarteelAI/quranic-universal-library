module Exporter
  class ExportTranslationChunk
    HARD_CODED_FOOTNOTES = {
      'sg' => 'singular',
      'pl' => 'plural',
      'dl' => 'dual'
    }

    def export(translation)
      text = translation&.text.to_s

      if text.blank?
        return {
          t: []
        }
      end

      translation_text_with_footnotes(translation)
    end

    protected

    def translation_text_with_footnotes(translation)
      text = translation.text.to_s

      doc = Nokogiri::HTML::DocumentFragment.parse(text)
      if is_bridges_translation?(translation)
        export_translation_chunks_(doc)
      else
        export_translation_chunks(doc)
      end
    end

    def export_translation_chunks(doc)
      footnotes_refs = {}
      footnotes = {}
      foot_note_counter = 1

      doc.children.each do |node|
        if node.name == 'text'
          next
        end

        id = node.attr('foot_note')
        if id.present? && (foot_note = fetch_footnote(id)).present?
          # Some footnote also has html tags tags, strip those tags
          foot_note_text = Nokogiri::HTML::DocumentFragment.parse(foot_note.text).text
          stripped = foot_note_text.tr(" ", ' ')

          footnotes[foot_note_counter] = stripped
          footnotes_refs[id] = foot_note_counter
          foot_note_counter += 1
        end
      end

      translation_chunks = []
      doc.children.each do |child|
        id = child.attr('foot_note')

        if id.present?
          if fetch_footnote(id).present?
            translation_chunks << {
              type: 'f',
              text: footnotes_refs[id]
            }
          end
        else
          translation_chunks << child.text.gsub(" ", " ") if child.text.presence.present?
        end
      end

      {
        t: translation_chunks,
        f: footnotes
      }
    end

    def export_translation_chunks_(doc)
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

      if footnotes.present?
        {
          t: translation_chunks,
          f: footnotes
        }
      else
        {
          t: translation_chunks
        }
      end
    end

    def is_bridges_translation?(translation)
      149 == translation.resource_content_id
    end

    def fetch_footnote(id)
      @footnotes ||= {}

      return @footnotes[id.to_i] if @footnotes[id.to_i] && @footnotes[id.to_i].text.present?

      if footnote = FootNote.where(id: id).first
        FootNote.where(resource_content_id: footnote.resource_content_id).each do |fn|
          @footnotes[fn.id] = fn
        end

        fn = (@footnotes[id.to_i] || footnote)
        fn if fn && fn.text.present?
      end
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