# This job import (subtype: translation) data from Draft::Content table Into WordTranslation And Tanslation table

module DraftContent
  class ApproveDraftTranslationJob < ApplicationJob
    sidekiq_options retry: 1, backtrace: true

    def perform(resource_content_id, draft_id = nil)
      @resource = ResourceContent.find(resource_content_id)
      raise "Invalid resource type" unless @resource.translation?

      PaperTrail.enabled = false
      if draft_id
        import_single Draft::Content.find(draft_id)
      else
        import_all
      end

      issues = @resource.run_after_import_hooks
      report_issues(issues)
      mark_todos_as_finished
    ensure
      PaperTrail.enabled = true
    end

    private

    # Single‑draft path
    def import_single(draft)
      if @resource.one_word?
        import_word(draft)
      else
        import_verse(draft)
      end
      draft.update_column(:imported, true)
      @resource.touch
    end

    # Bulk path
    def import_all
      Draft::Content
        .where(resource_content_id: @resource.id, imported: false)
        .find_each(batch_size: 1_000) do |draft|
        begin
          ActiveRecord::Base.transaction do
            if @resource.one_word?
              import_word(draft)
            else
              import_verse(draft)
            end
            draft.update_column(:imported, true)
          end
        rescue => e
          Rails.logger.error("[ApproveDraftTranslationJob] failed draft #{draft.id}: #{e.message}")
        end
      end
      @resource.touch
    end

    def import_verse(draft)
      v = draft.verse
      t = Translation.where(
        verse_id: v.id,
        resource_content_id: @resource.id
      ).first_or_initialize

      t.assign_attributes(
        text:               draft.draft_text.strip,
        language_id:        @resource.language_id,
        language_name:      @resource.language_name.downcase,
        priority:           @resource.priority || 5,
        verse_key:          v.verse_key,
        chapter_id:         v.chapter_id,
        verse_number:       v.verse_number,
        juz_number:         v.juz_number,
        hizb_number:        v.hizb_number,
        rub_el_hizb_number: v.rub_el_hizb_number,
        ruku_number:        v.ruku_number,
        surah_ruku_number:  v.surah_ruku_number,
        manzil_number:      v.manzil_number,
        page_number:        v.page_number
      )
      t.save!(validate: false)
    end

    def import_word(draft)
      w = draft.word
      wt = WordTranslation.where(
        word_id:             w.id,
        resource_content_id: @resource.id
      ).first_or_initialize

      wt.assign_attributes(
        text:          draft.draft_text.strip,
        language_id:   @resource.language_id,
        language_name: @resource.language_name.downcase,
        priority:      @resource.priority || 5,
        group_word_id: draft.meta_data&.dig('group_word_id'),
        group_text:    draft.meta_data&.dig('group_text')
      )
      wt.save!(validate: false)
    end

    def report_issues(issues)
      body =
        if issues.present?
          summary = issues.first(3).join(', ')
          "Imported latest changes. Found #{issues.size} issues: #{summary}. " \
            "<a href='/cms/admin_todos?q%5Bresource_content_id_eq%5D=#{@resource.id}&order=id_desc'>See details</a>."
        else
          "Imported latest changes."
        end

      ActiveAdmin::Comment.create!(
        namespace:       'cms',
        resource:        @resource,
        author_type:     'User',
        author_id:       1,    # system user
        body:            body
      )
    end

    def mark_todos_as_finished
      AdminTodo.where(resource_content_id: @resource.id).update_all(is_finished: true)
    end
  end
end
