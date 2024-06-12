module Importer
  class Base
    include Utils::StrongMemoize
    SANITIZER = Text::Sanitizer.new
    FULL_SANITIZER = Rails::Html::FullSanitizer.new

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

    def get_json(url, params={})
      response = with_rescue_retry([RestClient::Exceptions::ReadTimeout, RestClient::NotFound], retries: 3, raise_exception_on_limit: true) do
        rest_agent.get(url, params: params)
      end

      JSON.parse(response.body)
    rescue RestClient::NotFound => e
      log_message "======#{url} is 404====== params #{params}. #{e.message}"
      raise e
    end

    protected
    def log_message(message)
      puts message
    end

    def mechanize_agent
      strong_memoize :mechanize_agent do
        require 'mechanize'
        a=Mechanize.new
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

      text.to_s.strip
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