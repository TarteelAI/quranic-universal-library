module SeoHelper
  HOST = "https://qul.tarteel.ai"

  def seo_meta_tags(presenter)
    return unless presenter
    meta_data = presenter.meta_tags
    tags = []

    title = meta_data[:title]
    description = meta_data[:description]
    keywords = meta_data[:keywords]
    image = meta_data[:image]
    author = meta_data[:author] || "Tarteel AI"
    robots = meta_data[:robots] || "index, follow"

    tags << content_tag(:title, title)
    tags << tag.meta(name: 'description', content: description) if meta_data[:description].present?
    tags << tag.meta(name: 'keywords', content: keywords) if keywords.present?
    tags << tag.meta(name: 'robots', content: robots)
    tags << tag.meta(name: 'author', content: author)

    tags << tag.meta(property: 'og:site_name', content: 'Quranic Universal Library')
    tags << tag.meta(property: 'og:type', content: 'website')
    tags << tag.meta(property: 'og:title', content: title)
    tags << tag.meta(property: 'og:description', content: description) if description.present?
    tags << tag.meta(property: 'og:image', content: image)
    tags << tag.meta(property: 'og:image:width', content: '1200')
    tags << tag.meta(property: 'og:image:height', content: '630')
    tags << tag.meta(property: 'og:image:alt', content: 'Quranic Universal Library (QUL) logo')
    tags << tag.meta(property: 'og:url', content: canonical_url)
    tags << tag.meta(property: 'og:locale', content: 'en_US')

    tags << tag.meta(name: 'twitter:card', content: 'summary_large_image')
    tags << tag.meta(name: 'twitter:title', content: title)
    tags << tag.meta(name: 'twitter:description', content: description) if description.present?
    tags << tag.meta(name: 'twitter:image', content: image)
    tags << tag.meta(name: 'twitter:site', content: '@TarteelAI')

    tags << tag.link(rel: 'canonical', href: canonical_url)

    tags << content_tag(:script, json_ld_structured_data(title, description, image), type: 'application/ld+json')

    safe_join(tags)
  end

  def canonical_url
    "#{HOST}#{request.path}"
  end

  private

  def json_ld_structured_data(title, description, image)
    {
      "@context": "https://schema.org",
      "@type": "WebSite",
      name: "Quranic Universal Library",
      alternateName: "QUL",
      url: HOST,
      description: description,
      image: image,
      publisher: {
        "@type": "Organization",
        name: "Tarteel AI",
        url: "https://tarteel.ai",
        logo: {
          "@type": "ImageObject",
          url: "#{HOST}/favicon.svg"
        }
      },
      sameAs: [
        "https://github.com/TarteelAI/quranic-universal-library",
        "https://discord.gg/HAcGh8mfmj"
      ]
    }.to_json.html_safe
  end
end