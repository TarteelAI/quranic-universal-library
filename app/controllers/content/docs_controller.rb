# frozen_string_literal: true

module Content
  # /docs/:key, while the `content` page group is on (PageGroups), for page loads and Inertia
  # visits (Content::DocsRequest). Content::DocPage resolves the key; an unknown key is a 404. The
  # head keeps the old page's title and description.
  class DocsController < InertiaController
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
