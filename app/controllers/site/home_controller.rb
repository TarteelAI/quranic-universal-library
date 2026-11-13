# frozen_string_literal: true

module Site
  # The home page (/), while the `home` page group is on (PageGroups). The old landing page
  # (LandingController) answers otherwise. The head keeps the old page's title, description and
  # WebSite JSON-LD with its publisher.
  class HomeController < InertiaController
    def show
      @stats = Catalog::Stats.new.call
      @samples = Catalog::Samples.new.call
      @tools = SiteNav::ContributeTools.featured(helpers.developer_tools)
      @apps = AppDirectory.apps
      @showcase = @apps.first(AppDirectory::SHOWCASE_SIZE)

      render_inertia 'site/HomePage', meta: page_meta(
        title: 'Quranic Universal Library — Download Quran Data, JSON & APIs',
        description: 'Download free Quran data as JSON — translations, tafsir, word-by-word, audio recitations ' \
                     'and Uthmani/IndoPak scripts — plus developer tools and APIs from the Quranic Universal Library.',
        json_ld: {
          '@type': 'WebSite',
          name: PageMeta::SITE_NAME,
          alternateName: 'QUL',
          url: SeoHelper::HOST,
          image: PageMeta::IMAGE,
          publisher: {
            '@type': 'Organization',
            name: 'Tarteel AI',
            url: 'https://tarteel.ai',
            logo: { '@type': 'ImageObject', url: "#{SeoHelper::HOST}/favicon.svg" },
          },
        },
      )
    end
  end
end
