# frozen_string_literal: true

module DraftContent
  class ApproveDraftTranslationJob < ApproveDraftContentJob
    BATCH_SIZE = 1000

    private

    def import_from_legacy_table
      scope = Draft::Translation.includes(:foot_notes).where(resource_content_id: @resource.id)
      bulk_import(scope, Draft::Translation, footnotes: true)
    end

    def import_from_draft_content
      scope =
        if @draft_id
          Draft::Content.where(id: @draft_id)
        else
          Draft::Content.where(resource_content_id: @resource.id, imported: false)
        end

      bulk_import(scope, Draft::Content, footnotes: false)
    end

    def bulk_import(scope, draft_class, footnotes:)
      verse_ids = scope.distinct.pluck(:verse_id).compact
      verses = Verse.where(id: verse_ids).index_by(&:id)
      existing = Translation.where(resource_content_id: @resource.id, verse_id: verse_ids)
                            .pluck(:verse_id, :id).to_h

      scope.find_in_batches(batch_size: BATCH_SIZE) do |batch|
        inserts = []
        updates = []
        imported_ids = []
        footnote_drafts = []

        batch.each do |draft|
          verse = verses[draft.verse_id]
          next unless verse

          row = translation_row(draft, verse)
          imported_ids << draft.id

          if (id = existing[draft.verse_id])
            updates << row.merge(id: id)
          else
            inserts << row
          end

          footnote_drafts << draft if footnotes && draft.foot_notes.present?
        end

        Translation.insert_all(inserts) if inserts.any?
        Translation.upsert_all(updates, unique_by: :id) if updates.any?

        import_footnotes(footnote_drafts) if footnote_drafts.any?

        draft_class.where(id: imported_ids).update_all(imported: true) if imported_ids.any?
      end
    end

    def translation_row(draft, verse)
      {
        verse_id: verse.id,
        resource_content_id: @resource.id,
        text: draft.draft_text.strip,
        language_id: @resource.language_id,
        language_name: @resource.language_name&.downcase || '',
        resource_name: @resource.name,
        priority: @resource.priority || 5,
        verse_key: verse.verse_key,
        chapter_id: verse.chapter_id,
        verse_number: verse.verse_number,
        juz_number: verse.juz_number,
        hizb_number: verse.hizb_number,
        rub_el_hizb_number: verse.rub_el_hizb_number,
        ruku_number: verse.ruku_number,
        surah_ruku_number: verse.surah_ruku_number,
        manzil_number: verse.manzil_number,
        page_number: verse.page_number
      }
    end

    def import_footnotes(footnote_drafts)
      verse_ids = footnote_drafts.map(&:verse_id)
      translations = Translation.where(resource_content_id: @resource.id, verse_id: verse_ids)
                                .index_by(&:verse_id)

      footnote_drafts.each do |draft|
        translation = translations[draft.verse_id]
        next unless translation

        footnote_resource_id = draft.foot_notes.first.resource_content_id ||
                               @resource.meta_value('related-footnote-resource-id')

        text = translation.text
        draft.foot_notes.each do |draft_footnote|
          footnote = FootNote.create!(
            text: draft_footnote.draft_text,
            translation: translation,
            language_id: @resource.language_id,
            language_name: @resource.language_name&.downcase || '',
            resource_content_id: footnote_resource_id
          )
          text = text.sub(/foot_note=(['"]?)#{draft_footnote.id}\1/, "foot_note=#{footnote.id}")
        end

        translation.update_column(:text, text.strip)
      end
    end
  end
end
