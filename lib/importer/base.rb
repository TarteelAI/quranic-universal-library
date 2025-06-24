module Importer
  class Base
    include Utils::StrongMemoize
    TAFSIR_SANITIZER = Utils::TextSanitizer::TafsirSanitizer.new
    FULL_SANITIZER = Rails::Html::FullSanitizer.new

    attr_reader :issues

    def initialize
      @issues = []
    end

    def create_draft_tafsir(text, verse, resource, grouping_ayah)
      draft_tafsir = Draft::Tafsir
                       .where(
                         resource_content_id: resource.id,
                         verse_id: verse.id
                       ).first_or_initialize

      existing_tafsir = Tafsir
                          .where(resource_content_id: resource.id)
                          .where(":ayah >= start_verse_id AND :ayah <= end_verse_id ", ayah: verse.id)
                          .first

      draft_tafsir.tafsir_id = existing_tafsir&.id
      draft_tafsir.current_text = existing_tafsir&.text
      draft_tafsir.draft_text = text
      draft_tafsir.text_matched = existing_tafsir&.text == text

      draft_tafsir.verse_key = verse.verse_key

      draft_tafsir.group_verse_key_from = grouping_ayah.first.verse_key
      draft_tafsir.group_verse_key_to = grouping_ayah.last.verse_key
      draft_tafsir.group_verses_count = Verse.where(id: grouping_ayah.first.id..grouping_ayah.last.id).order('verse_index ASC').size
      draft_tafsir.start_verse_id = grouping_ayah.first.id
      draft_tafsir.end_verse_id = grouping_ayah.last.id
      draft_tafsir.group_tafsir_id = verse.id

      draft_tafsir.save(validate: false)
      draft_tafsir
    end

    def get_html(url)
      mechanize_agent.get(url)
    end

    def get_json(url, params = {})
      response = with_rescue_retry([RestClient::Exceptions::ReadTimeout, RestClient::NotFound, Zlib::DataError], retries: 3, raise_exception_on_limit: true) do
        rest_agent.get(url, params: params)
      end

      JSON.parse(response.body)
    rescue RestClient::NotFound => e
      log_message "======#{url} is 404====== params #{params}. #{e.message}"
      raise e
    end

    protected


    def run_after_import_hooks(resource)
      resource.run_draft_import_hooks

      if @issues.present?
        issues_group = @issues.group_by do |issue|
          issue[:tag]
        end

        issues_group.keys.each do |issue_tag|
          issue_description = issues_group[issue_tag].map do |issue|
            issue[:text]
          end

          AdminTodo.create(
            is_finished: false,
            tags: issue_tag,
            resource_content_id: resource.id,
            description: "#{resource.source_slug} parse issues in #{resource.name}(#{resource.id}). <div>#{issue_tag}</div>\n#{issue_description.uniq.join(', ')}"
          )
        end
      end

      if resource.id == 127
        # This is Ubzek translation, we've a Latin version of this translation
        # update the latin version too

        latin = ResourceContent.find(55)
        latin_footnote = ResourceContent.find(195)
        converter = Utils::CyrillicToLatin.new
        Draft::FootNote.where(resource_content_id: latin_footnote.id).delete_all

        Draft::Translation.where(resource_content_id: resource.id).each do |translation|
          data = translation.meta_value('source_data')
          draft_translation = create_translation_with_footnote(
            translation.verse,
            latin,
            latin_footnote,
            'uzbek_sadiq_latin',
            data,
            report_foonote_issues: false
          )

          text = converter.to_latin(draft_translation.draft_text)

          draft_translation.update_columns(
            draft_text: text,
            text_matched: remove_footnote_tag(text) == remove_footnote_tag(draft_translation.current_text)
          )

          draft_translation.foot_notes.each do |foot_note|
            text = converter.to_latin(foot_note.draft_text)
            foot_note.update_columns(
              draft_text: text,
              text_matched: text == foot_note.current_text
            )
          end
        end
      end

      resource.save(validate: false)
    end


    def log_message(message)
      puts message
    end

    def log_issue(issue)
      @issues << issue

      log_message "#{issue[:tag]}: #{issue[:text]}"
    end

    def mechanize_agent
      strong_memoize :mechanize_agent do
        require 'mechanize'
        a = Mechanize.new
        a.verify_mode = OpenSSL::SSL::VERIFY_NONE
        a
      end
    end

    def rest_agent
      RestClient
    end

    # Remove HTML tags and return simple text
    def sanitize(text)
      FULL_SANITIZER.sanitize(text)
    end

    def fix_encoding(text)
      text = if text.valid_encoding?
               text
             else
               text.scrub
             end

      text.sub(/^[\s\u00A0]+|[\s\u00A0]+$/, '').strip
    end

    def split_paragraphs(text)
      return [] if text.blank?

      text.to_str.split(/\r?\n+r?/).select do |para|
        para.presence.present?
      end
    end

    def simple_format(text)
      paragraphs = split_paragraphs(text)

      if paragraphs.size == 1
        paragraphs[0].strip
      else
        paragraphs.map! { |paragraph|
          "<p>#{paragraph.strip}</p>"
        }.join('').html_safe
      end
    end
  end
end