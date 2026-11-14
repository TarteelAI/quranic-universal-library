# frozen_string_literal: true

module Content
  # The docs side navigation and the docs index: the categories of config/docs.yml in order, each
  # with its pages in reading order. A page's children follow it, one level deeper.
  module DocsNavigation
    Category = Data.define(:key, :title, :description, :badge, :pages)
    Page = Data.define(:key, :title, :depth)

    def self.categories
      DocsManifest.categories.map do |category|
        Category.new(key: category.slug, title: category.title, description: category.description,
                     badge: category.badge, pages: pages(category.pages, 0),)
      end
    end

    def self.pages(pages, depth)
      pages.flat_map { |page| [Page.new(key: page.slug, title: page.title, depth:), *pages(page.children, depth + 1)] }
    end
  end
end
