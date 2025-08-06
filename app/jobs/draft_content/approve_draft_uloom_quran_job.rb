# frozen_string_literal: true

module DraftContent
  class ApproveDraftUloomQuranJob < ApproveDraftContentJob
    private

    def import_data
      if @draft_id
        draft = Draft::Content.find(@draft_id)
        import_single(draft)
      else
        import_all
      end
    end

    def import_single(draft)
      start_loc, end_loc = draft.location.to_s.split('-')
      from_val = extract_number(start_loc)
      to_val = extract_number(end_loc || start_loc)

      attrs = {
        resource_content_id: @resource.id,
        language_id: @resource.language_id,
        language_name: @resource.language_name&.downcase || '',
        chapter_id: draft.chapter_id,
        meta_data: draft.meta_data,
        text: draft.draft_text.to_s.strip
      }

      if draft.word_id
        import_by_word(attrs.merge(
          verse_id: draft.verse_id,
          word_id: draft.word_id,
          from: from_val,
          to: to_val
        ))
      elsif draft.verse_id
        import_by_verse(attrs.merge(
          verse_id: draft.verse_id,
          from: from_val,
          to: to_val
        ))
      else
        import_by_chapter(attrs)
      end
      draft.update_column(:imported, true)
    end

    def import_all
      Draft::Content.where(resource_content_id: @resource.id, imported: false)
                    .find_each(batch_size: 500) { |draft| import_single(draft) }
    end

    def import_by_word(attrs)
      record = UloomQuranByWord.find_or_initialize_by(
        resource_content_id: attrs[:resource_content_id],
        id: @draft_id
      )
      record.assign_attributes(attrs)
      record.save!(validate: false)
    end

    def import_by_verse(attrs)
      record = UloomQuranByVerse.find_or_initialize_by(
        resource_content_id: attrs[:resource_content_id],
        id: @draft_id
      )
      record.assign_attributes(attrs)
      record.save!(validate: false)
    end

    def import_by_chapter(attrs)
      record = UloomQuranByChapter.find_or_initialize_by(
        resource_content_id: attrs[:resource_content_id],
        chapter_id: attrs[:chapter_id]
      )
      record.assign_attributes(attrs)
      record.save!(validate: false)
    end

    def extract_number(loc_str)
      loc_str.to_s.scan(/\d+/).last.to_i
    end
  end
end