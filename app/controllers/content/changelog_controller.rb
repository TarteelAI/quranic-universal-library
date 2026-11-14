# frozen_string_literal: true

module Content
  # /changelog and /changelog/:id, while the `content` page group is on (PageGroups): the
  # published changelog entries (Content::Changelog). The old /change_logs URLs redirect here.
  class ChangelogController < InertiaController
    def index
      render_inertia 'content/ChangelogPage', locals: Changelog.page(params[:page]).to_h, meta: page_meta(
        title: 'Changelog - QUL',
        description: 'Updates and fixes to the resources of the Quranic Universal Library, newest first.',
      )
    end

    def show
      @entry = Changelog.find(params[:id])
      render_inertia 'content/ChangelogEntryPage', meta: page_meta(
        title: "#{@entry.title} - Changelog - QUL",
        description: @entry.excerpt,
      )
    end
  end
end
