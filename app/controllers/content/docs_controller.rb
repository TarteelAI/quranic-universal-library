# frozen_string_literal: true

module Content
  # /docs and /docs/:key, while the `content` page group is on (PageGroups), for page loads and
  # Inertia visits (Content::DocsRequest). Content::DocPage resolves the key; an unknown key is a
  # 404. Both pages carry the docs navigation, and the head keeps the old pages' titles and
  # descriptions.
  class DocsController < InertiaController
    before_action { @navigation = DocsNavigation.categories }

    def index
      render_inertia 'content/DocsIndexPage', meta: page_meta(
        title: 'QUL Documentation — Guides, Datasets & API Reference',
        description: CommunityPresenter::DOCS_INDEX_DESCRIPTION,
      )
    end

    def show
      @doc = DocPage.find(params[:key]) or raise ActiveRecord::RecordNotFound, "Unknown docs key #{params[:key]}"
      render_inertia 'content/DocsPage', meta: page_meta(
        title: [@doc.title, doc_category&.title, 'QUL Documentation'].compact.uniq.join(' — '),
        description: @doc.description.presence || doc_category&.description.presence ||
                     CommunityPresenter::DOCS_INDEX_DESCRIPTION,
        json_ld: { '@type': 'TechArticle',
                   isPartOf: { '@type': 'WebSite', name: PageMeta::SITE_NAME, url: SeoHelper::HOST }, },
      )
    end

    private

    def doc_category
      @doc_category ||= DocsManifest.category(@doc.position.category&.key)
    end
  end
end
