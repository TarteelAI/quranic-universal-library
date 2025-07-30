# This job import Tafsir data from Draft::Content table Into Tafsir table

module DraftContent
  class ApproveDraftTafsirJob < ApplicationJob
    sidekiq_options retry: 1, backtrace: true

    def perform(resource_content_id, draft_id = nil)
      resource = ResourceContent.find(resource_content_id)
      raise "Invalid resource type" unless resource.tafsir?

      PaperTrail.enabled = false

      draft_id ? import_single_tafsir(resource, draft_id) : import_all_tafsirs(resource)

      issues = resource.run_after_import_hooks
      report_issues(resource, issues)
      mark_todos_as_finished(resource)
    ensure
      PaperTrail.enabled = true
    end

    private

    def import_single_tafsir(resource, draft_id)
      draft = Draft::Content.find(draft_id)
      import_tafsir_draft(resource, draft)
    end

    def import_all_tafsirs(resource)
      Draft::Content.where(resource_content_id: resource.id, imported: false)
                    .includes(:verse)
                    .find_each(batch_size: 500) do |draft|
        import_tafsir_draft(resource, draft)
      end
    end

    def import_tafsir_draft(resource, draft)
      start_loc, end_loc = draft.location.to_s.split('-')
      chapter_str, start_str = start_loc.split(':')
      end_str = (end_loc || start_str)
      start_num = start_str.to_i
      end_num   = end_str.to_i

      verse_keys = (start_num..end_num).map { |v| "#{chapter_str}:#{v}" }

      tafsir = Tafsir.find_or_initialize_by(resource_content_id: resource.id, verse_id: draft.verse_id)
      tafsir.assign_attributes(
        text: draft.draft_text.to_s.strip,
        language_id: resource.language_id,
        language_name: resource.language_name.downcase,
        resource_name: resource.name,
        verse_key: verse_keys.first,
        start_verse_id: draft.verse_id,
        end_verse_id: draft.verse_id + (end_num - start_num),
        group_tafsir_id: draft.verse_id,
        group_verses_count: verse_keys.size
      )
      tafsir.save!(validate: false)
      draft.update_column(:imported, true)
    end

    def report_issues(resource, issues); end
    def mark_todos_as_finished(resource); end
  end
end
