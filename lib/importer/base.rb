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

    # Runs hooks, logs any import issues, verifies imported keys, and handles Uzbek Latin conversion
    def run_after_import_hooks(resource, source_key: nil, imported_keys: nil)
      resource.run_draft_import_hooks

      if @issues.present?
        issues_group = @issues.group_by { |issue| issue[:tag] }
        issues_group.each do |issue_tag, issues|
          descriptions = issues.map { |i| i[:text] }.uniq
          AdminTodo.create(
            is_finished: false,
            tags: issue_tag,
            resource_content_id: resource.id,
            description: "#{resource.source_slug} parse issues in #{resource.name}(#{resource.id}). <div>#{issue_tag}</div>\n#{descriptions.join(', ')}"
          )
        end
      end

      # Verify JSON keys vs imported keys
      if source_key && imported_keys
        begin
          sources = get_json('https://tafsir.app/sources/sources.json')
          json_entry = sources[source_key]
          json_keys = json_entry && json_entry['keys']

          if json_keys.is_a?(Array)
            missing = json_keys - imported_keys.keys
            extra   = imported_keys.keys - json_keys

            log_message "\n=== Import Verification for '#{source_key}' ==="
            log_message "Keys in JSON: #{json_keys.inspect}"
            log_message "Imported keys: #{imported_keys.keys.inspect}"

            if missing.any?
              log_message "Missing keys: #{missing.inspect}"
            else
              log_message "No missing keys. All JSON keys imported."
            end

            if extra.any?
              log_message "Extra imported keys not in JSON: #{extra.inspect}"
            end
          else
            log_message "No 'keys' array found in sources.json for '#{source_key}'"
          end
        rescue => e
          log_message "Error during import verification for '#{source_key}': #{e.message}"
        end
      end

      if resource.id == 127
        # This is Uzbek translation, we have a Latin version too
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
            note_text = converter.to_latin(foot_note.draft_text)
            foot_note.update_columns(
              draft_text: note_text,
              text_matched: note_text == foot_note.current_text
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
      text = text.valid_encoding? ? text : text.scrub
      text.strip
    end

    def split_paragraphs(text)
      return [] if text.blank?
      text.to_str.split(/\r?\n+\r?/).select(&:present?)
    end

    def simple_format(text)
      paragraphs = split_paragraphs(text)
      return paragraphs.first.strip if paragraphs.size == 1

      paragraphs.map { |para| "<p>#{para.strip}</p>" }.join('').html_safe
    end
  end
end