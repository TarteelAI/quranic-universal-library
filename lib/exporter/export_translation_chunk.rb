module Exporter
  class ExportTranslationChunk
    def export(translation)
      text = translation.text.to_s
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
        export_bridres_with_footnote(doc)
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
          stripped = foot_note_text.tr(" ", '').strip

          footnotes[foot_note_counter] = stripped
          footnotes_refs[id] = foot_note_counter
          foot_note_counter += 1
        end
      end

      translation_chunks = []
      doc.children.each do |child|
        id = child.attr('foot_note')
        next if fetch_footnote(id).blank?

        if id.present?
          translation_chunks << {
            type: 'f',
            text: footnotes_refs[id]
          }
        else
          translation_chunks << child.text if child.text.presence.present?
        end
      end

      {
        t: translation_chunks,
        f: footnotes
      }
    end

    def export_bridres_with_footnote(doc)
      # i class s formatting
      # span class h (qirat)
      # sup or a.sup footnote

      hard_coded_footnotes = ['sg', 'pl', 'dl']
      foot_note_tags = ['sup', 'a']

      foot_note_counter = 1
      footnotes = {}
      translation_chunks = []

      doc.children.each do |node|
        if foot_note_tags.include?(node.name) || hard_coded_footnotes.include?(node.text.strip)
          if hard_coded_footnotes.include?(node.text.strip)
            translation_chunks << { f: node.text.strip }
          else
            id = node.attr('foot_note')

            if id.present? && (foot_note = fetch_footnote(id)).present?
              translation_chunks << { f: foot_note_counter }
              foot_note_counter += 1
            end
          end
        elsif node.name == 'i'
          translation_chunks << { i: node.text.strip }
        elsif node.name == 'span'
          translation_chunks << { b: node.text.strip }
        end
      end

      {
        t: translation_chunks,
        f: footnotes
      }
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
  end
end