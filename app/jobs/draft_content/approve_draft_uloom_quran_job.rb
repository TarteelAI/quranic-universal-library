# This job import (subtype: UloomQuran) data from Draft::Content table Into UloomQuran table

module DraftContent
  class ApproveDraftUloomQuranJob < ApplicationJob
    sidekiq_options retry: 1, backtrace: true

    def perform(resource_content_id, draft_id = nil)
      resource = ResourceContent.find(resource_content_id)
      PaperTrail.enabled = false
      raise "Invalid resource type" unless resource.uloom_quran?

      draft_id ? import_single(resource, draft_id) : import_all(resource)

      issues = resource.run_after_import_hooks
      report_issues(resource, issues)
      mark_todos_as_finished(resource)
      PaperTrail.enabled = true
    end

    private

    def import_single(resource, draft_id)
      draft = Draft::Content.find(draft_id)
      start_loc, end_loc = draft.location.to_s.split('-')
      from_val = extract_number(start_loc)
      to_val   = extract_number(end_loc || start_loc)

      attrs = {
        resource_content_id: resource.id,
        language_id:         resource.language_id,
        language_name:       resource.language_name.downcase,
        chapter_id:          draft.chapter_id,
        meta_data:           draft.meta_data,
        text:                draft.draft_text.to_s.strip
      }

      if draft.word_id
        # by-word
        record = UloomQuranByWord.find_or_initialize_by(resource_content_id: resource.id, id: draft.id)
        record.assign_attributes(attrs.merge(
          verse_id: draft.verse_id,
          word_id:  draft.word_id,
          from:     from_val,
          to:       to_val
        ))
      elsif draft.verse_id
        # by-verse
        record = UloomQuranByVerse.find_or_initialize_by(resource_content_id: resource.id, id: draft.id)
        record.assign_attributes(attrs.merge(
          verse_id: draft.verse_id,
          from:     from_val,
          to:       to_val
        ))
      else
        # by-chapter
        record = UloomQuranByChapter.find_or_initialize_by(resource_content_id: resource.id, chapter_id: draft.chapter_id)
        record.assign_attributes(attrs)
      end

      record.save!(validate: false)
      draft.update_column(:imported, true)
    end

    def import_all(resource)
      Draft::Content.where(resource_content_id: resource.id, imported: false)
                    .find_each(batch_size: 500) do |draft|
        import_single(resource, draft.id)
      end
    end

    def extract_number(loc_str)
      loc_str.to_s.scan(/\d+/).last.to_i
    end

    def report_issues(resource, issues)
      body = issues.present? ? "Imported with #{issues.size} issues" : "Imported UloomQuran successfully"
      ActiveAdmin::Comment.create(namespace: 'cms', resource: resource, author_id: 1,
                                  author_type: 'User', body: body)
    end

    def mark_todos_as_finished(resource)
      AdminTodo.where(resource_content_id: resource.id).update_all(is_finished: true)
    end
  end
end
