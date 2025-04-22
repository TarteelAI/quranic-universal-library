module DraftContent
  class RemoveDraftContentJob < ApplicationJob
    sidekiq_options retry: 1, backtrace: true

    def perform(id)
      resource = ResourceContent.find(id)

      if resource.tafsir?
        remove_draft_tafsirs(resource)
      elsif resource.translation?
        if resource.one_word?
          remove_draft_word_translations(resource)
        else
          remove_draft_translations(resource)
        end
      else
        raise "Unsupported resource type"
      end

      clean_up_todos(resource)
    end

    protected

    def clean_up_todos(resource)
      AdminTodo
        .where(resource_content_id: resource.id)
        .delete_all
    end

    def remove_draft_tafsirs(resource)
      Draft::Tafsir
        .where(resource_content_id: resource.id)
        .delete_all
    end

    def remove_draft_translations(resource)
      translations = Draft::Translation
                       .includes(:foot_notes)
                       .where(resource_content_id: resource.id)

      translations.find_each(batch_size: 500) do |draft|
        draft.foot_notes.delete_all
        draft.delete
      end
    end

    def remove_draft_word_translations(resource)
      Draft::WordTranslation.where(resource_content_id: resource.id).delete_all
    end
  end
end