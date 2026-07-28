# frozen_string_literal: true

module DraftContent
  class ApproveDraftWordTranslationJob < ApproveDraftContentJob
    BATCH_SIZE = 1000

    private

    def import_from_legacy_table
      scope = Draft::WordTranslation.where(resource_content_id: @resource.id)
      import_drafts(scope, Draft::WordTranslation, group: false)
    end

    def import_from_draft_content
      scope =
        if @draft_id
          Draft::Content.where(id: @draft_id)
        else
          Draft::Content.where(resource_content_id: @resource.id, imported: false)
        end

      import_drafts(scope, Draft::Content, group: true)
    end

    def import_drafts(scope, draft_class, group:)
      existing = WordTranslation.where(resource_content_id: @resource.id).pluck(:word_id, :id).to_h

      scope.find_in_batches(batch_size: BATCH_SIZE) do |batch|
        inserts = []
        updates = []
        imported_ids = []

        batch.each do |draft|
          next if draft.word_id.blank?

          row = translation_row(draft, group: group)
          imported_ids << draft.id

          if (id = existing[draft.word_id])
            updates << row.merge(id: id)
          else
            inserts << row
          end
        end

        WordTranslation.insert_all(inserts) if inserts.any?
        WordTranslation.upsert_all(updates, unique_by: :id) if updates.any?
        draft_class.where(id: imported_ids).update_all(imported: true) if imported_ids.any?
      end
    end

    def translation_row(draft, group:)
      row = {
        word_id: draft.word_id,
        resource_content_id: @resource.id,
        text: draft.draft_text.strip,
        language_id: @resource.language_id,
        language_name: @resource.language_name&.downcase || '',
        priority: @resource.priority || 5
      }

      if group
        row[:group_word_id] = draft.meta_data&.dig('group_word_id')
        row[:group_text] = draft.meta_data&.dig('group_text')&.strip
      end

      row
    end
  end
end
