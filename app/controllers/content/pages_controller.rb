# frozen_string_literal: true

module Content
  # /faq, /credits and /tools, while the `content` page group is on (PageGroups). They read what
  # the old pages read: Faq.published; Contributor.published, the acknowledgements in
  # ApplicationHelper#contributors and the GitHub code contributors; and the contribution tools
  # (ToolsHelper#developer_tools) in the Contribute menu's groups. The tools overview links to the
  # old tool pages, which keep enforcing access.
  class PagesController < InertiaController
    def faq
      @items = Faq.published
      render_inertia 'content/FaqPage', meta: page_meta(
        title: 'FAQ - QUL',
        description: 'Answers to common questions about the Quranic Universal Library: what it holds, how to ' \
                     'download and use its resources, and how to contribute.',
      )
    end

    def credits
      @organizations = Contributor.published.with_attached_logo.order(:id)
      @acknowledgements = helpers.contributors
      @code_contributors = GithubService.fetch_contributors(limit: 20)
      render_inertia 'content/CreditsPage', meta: page_meta(
        title: 'Credits - QUL',
        description: 'The people, projects and organizations whose work made the resources and tools of the ' \
                     'Quranic Universal Library possible.',
      )
    end

    def tools
      @groups = SiteNav::ContributeTools.overview(helpers.developer_tools)
      render_inertia 'content/ToolsPage', meta: page_meta(
        title: 'Contribution tools - QUL',
        description: 'Tools to check and fix Quran data in QUL: translations, tafsirs, mushaf layouts, tajweed, ' \
                     'audio segments, word data and more.',
      )
    end
  end
end
