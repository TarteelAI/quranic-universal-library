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

    tags << content_tag(:title, title)
    tags << tag.meta(name: 'description', content: description) if meta_data[:description].present?
    tags << tag.meta(name: 'keywords', content: keywords) if keywords.present?

    tags << tag.meta(property: 'og:site_name', content: 'Quranic Universal Library')
    tags << tag.meta(property: 'og:type', content: 'website')
    tags << tag.meta(property: 'og:title', content: title)
    tags << tag.meta(property: 'og:description', content: description)
    tags << tag.meta(property: 'og:image', content: image)
    tags << tag.meta(property: 'og:url', content: canonical_url)

    tags << tag.meta(name: 'twitter:card', content: 'summary_large_image')
    tags << tag.meta(name: 'twitter:title', content: title)
    tags << tag.meta(name: 'twitter:description', content: description)
    tags << tag.meta(name: 'twitter:image', content: image)

    tags << tag.link(rel: 'canonical', href: canonical_url)

    safe_join(tags)
  end

  def canonical_url
    "#{HOST}#{request.path}"
  end
end