# frozen_string_literal: true

module DraftContent
  class ApproveDraftSurahInfoJob < ApproveDraftContentJob
    private

    def import_data
      scope = Draft::SurahInfo.where(resource_content_id: @resource.id, imported: false)
      scope = scope.where(id: @draft_id) if @draft_id

      # A surah can have several suggestions: the latest approved one wins,
      # if none is approved the latest one wins (find_each goes in id order).
      picked = {}
      imported_ids = []

      scope.find_each do |draft|
        imported_ids << draft.id
        picked[draft.chapter_id] = draft if prefer?(draft, picked[draft.chapter_id])
      end

      existing = ChapterInfo
                   .where(resource_content_id: @resource.id, chapter_id: picked.keys)
                   .index_by(&:chapter_id)

      picked.each do |chapter_id, draft|
        info = existing[chapter_id] || ChapterInfo.new(chapter_id: chapter_id, resource_content_id: @resource.id)
        info.short_text = draft.draft_short_text.to_s.strip
        info.text = draft.draft_text.to_s.strip
        info.language_id = @resource.language_id
        info.language_name = @resource.language_name&.downcase
        info.save(validate: false)
      end

      Draft::SurahInfo.where(id: imported_ids).update_all(imported: true)
    end

    def prefer?(draft, current)
      current.nil? || draft.need_review == false || current.need_review != false
    end
  end
end
