class DocsManifest
  MANIFEST_PATH = Rails.root.join("config/docs.yml").freeze

  Category = Struct.new(:slug, :title, :description, :icon, :accent, :badge, :pages, keyword_init: true)
  Page = Struct.new(:slug, :title, :children, keyword_init: true)

  class << self
    def categories
      load.values
    end

    def category(slug)
      load[slug.to_s]
    end

    def category_for_page(slug)
      slug = slug.to_s
      load.values.find { |category| category.pages.any? { |page| page_matches?(page, slug) } }
    end

    def title_for(slug)
      titles[slug.to_s]
    end

    def reload!
      @load = nil
      @titles = nil
    end

    private

    def load
      @load ||= build
    end

    def titles
      @titles ||= load.values.each_with_object({}) do |category, memo|
        collect_titles(category.pages, memo)
      end
    end

    def collect_titles(pages, memo)
      pages.each do |page|
        memo[page.slug] = page.title
        collect_titles(page.children, memo)
      end
    end

    def build
      raw = YAML.safe_load(File.read(MANIFEST_PATH)) || {}
      categories = raw.fetch("categories", [])

      categories.each_with_object({}) do |attrs, memo|
        category = Category.new(
          slug: attrs["slug"],
          title: attrs["title"],
          description: attrs["description"],
          icon: attrs["icon"],
          accent: attrs["accent"],
          badge: attrs["badge"],
          pages: build_pages(attrs.fetch("pages", []))
        )
        memo[category.slug] = category
      end
    end

    def build_pages(pages)
      pages.map do |page|
        Page.new(
          slug: page["slug"],
          title: page["title"],
          children: build_pages(page.fetch("children", []))
        )
      end
    end

    def page_matches?(page, slug)
      return true if page.slug == slug

      page.children.any? { |child| page_matches?(child, slug) }
    end
  end
end
