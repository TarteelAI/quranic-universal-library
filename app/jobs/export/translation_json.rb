=begin
ExportService::TRANSLATION_NAME_MAPPIMG.keys.each do |id|
  Export::TranslationJson.perform_later(id, 1)
end

ResourceContent.translations.approved.with_footnotes.each do |r|
  Export::TranslationJson.perform_later(r.id, 1)
end
=end

module Export
  class TranslationJson < ApplicationJob
    attr_reader :file_name,
                :resource_content
    STORAGE_PATH = "#{Rails.root}/public/exported_databases"

    def perform(resource_id, user_id, use_nested_array_format = false)
      @resource_content = ResourceContent.find(resource_id)
      @resource_content.touch # Update version

      setup

      if use_nested_array_format
        export_nested_array
      else
        export_data
      end

      compress if Rails.env.production?

      if user_id.present? && Rails.env.production?
        user = User.find(user_id)
        send_email("#{file_name}.bz2", user)
      end

      # return the db file path
      Rails.env.production? ? "#{file_name}.bz2" : file_name
    end

    protected

    def setup(versioned: true)
      require 'fileutils'

      name = ExportService.new(resource_content).get_export_file_name
      file_path = STORAGE_PATH

      FileUtils::mkdir_p file_path

      if versioned
        @file_name = "#{file_path}/#{name}-#{resource_content.updated_at.to_i}.json"
      else
        @file_name = "#{file_path}/#{name}.json"
      end
    end

    def export_nested_array
      data = []

      Chapter.order('chapter_number ASC').each do |chapter|
        data[chapter.id - 1] = []
        chapter.verses.order('verse_number ASC').each do |verse|
          translation = Translation.where(
            resource_content_id: resource_content.id,
            verse_id: verse.id
          ).first

          doc = Nokogiri::HTML::DocumentFragment.parse(translation&.text.to_s)
          doc.css('sup, a.sup').each do |node|
            node.remove
          end

          if resource_content.id == 149
            # Bridges qiraat footnote
            doc.css('span, i').each do |a_tag|
              content = a_tag.content
              a_tag.replace(content)
            end
          end

          data[chapter.id - 1] << doc.to_s.strip
        end
      end

      File.open(file_name, 'wb') do |file|
        file << JSON.generate(data, { state: JsonNoEscapeHtmlState.new })
      end
    end

    def export_data
      json = {}

      Chapter.order('chapter_number ASC').each do |chapter|
        chapter.verses.order('verse_number ASC').each do |verse|
          translation = Translation.where(
            resource_content_id: resource_content.id,
            verse_id: verse.id
          ).first

          json[verse.verse_key] = translation_text_with_footnotes(translation)
        end
      end

      File.open(file_name, 'wb') do |file|
        file << JSON.generate(json, { state: JsonNoEscapeHtmlState.new })
      end
    end

    def compress
      `bzip2 #{file_name}`
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
      last_node_was_footnote = false

      doc.children.each do |node|
        if foot_note_tags.include?(node.name) || hard_coded_footnotes.include?(node.text.strip)
          last_node_was_footnote = true

          if hard_coded_footnotes.include?(node.text.strip)
            translation_chunks << { f: node.text.strip }
          else
            id = node.attr('foot_note')

            if id.present? && (foot_note = FootNote.where(id: id).first).present?
              foot_note_text = Nokogiri::HTML::DocumentFragment.parse(foot_note.text).text
              stripped = foot_note_text.tr(" ", '').strip

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

    def translation_text_with_footnotes(translation)
      text = translation&.text
      footnotes_refs = {}
      footnotes = {}

      if text.blank? || (!text.include?('<sup') && !translation.resource_content_id == 149)
        result = {
          t: [text.to_s.strip]
        }
      else
        doc = Nokogiri::HTML::DocumentFragment.parse(text)
        if translation.resource_content_id == 149
          result = export_bridres_with_footnote(doc)
        else
          foot_note_counter = 1
          doc.children.each do |node|
            if node.name == 'text'
              next
            end

            id = node.attr('foot_note')
            if id.present? && (foot_note = FootNote.where(id: id).first).present?
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

            if id.present?
              translation_chunks << {
                f: footnotes_refs[id]
              }
            else
              translation_chunks << child.text if child.text.presence.present?
            end
          end

          result = {
            t: translation_chunks,
            f: footnotes
          }
        end
      end

      result
    end

    def format_footnote(text)
      doc = Nokogiri::HTML::DocumentFragment.parse(text)

      if (doc.children.size == 1 && doc.search('p').size == 1)
        text = doc.text
      end

      text.gsub(' ', ' ').strip
    end

    def send_email(zip_path, user)
      DeveloperMailer.notify(
        to: user.email,
        subject: "#{@resource_content.name} files export",
        message: "Please see the attached zip",
        file_path: zip_path
      ).deliver_now
    end
  end
end