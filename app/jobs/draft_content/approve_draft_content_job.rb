# frozen_string_literal: true

module DraftContent
  class ApproveDraftContentJob < ApplicationJob
    sidekiq_options retry: 1, backtrace: true

    def perform(resource_content_id, draft_id = nil, use_draft_content: false)
      @resource = ResourceContent.find(resource_content_id)
      @draft_id = draft_id
      @use_draft_content = use_draft_content

      PaperTrail.enabled = false
      import_data
      run_post_import_tasks
    ensure
      PaperTrail.enabled = true
    end

    private

    def import_data
      if @use_draft_content
        import_from_draft_content
      else
        import_from_legacy_table
      end
    end

    def import_from_draft_content
      if @draft_id
        import_single_draft
      else
        import_all_drafts
      end
    end

    def run_post_import_tasks
      issues = @resource.run_after_import_hooks
      report_issues(issues)
      mark_todos_as_finished
      @resource.touch
    end

    def report_issues(issues)
      return if issues.blank?

      body = "Found #{issues.size} issues after import. First: #{issues.first(3).join(', ')}"
      ActiveAdmin::Comment.create(
        namespace: 'cms',
        resource: @resource,
        author_type: 'User',
        author_id: 1,
        body: body
      )
    end

    def mark_todos_as_finished
      AdminTodo.where(resource_content_id: @resource.id).update_all(is_finished: true)
    end
  end
end