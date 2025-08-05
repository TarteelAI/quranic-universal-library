module SeoHelper
  HOST = "https://qul.tarteel.ai"

  def seo_meta_tags(presenter)
    return unless presenter
    meta_data = presenter.meta_tags
    tags = []

    tags << content_tag(:title, presenter.meta_title) if presenter.meta_title.present?
    tags << tag.meta(name: 'description', content: meta_data[:description]) if meta_data[:description].present?
    tags << tag.meta(name: 'keywords', content: meta_data[:keywords]) if meta_data[:keywords].present?

    # Open Graph tags
    tags << tag.meta(property: 'og:site_name', content: meta_data[:og][:site_name]) if meta_data[:og][:site_name].present?
    tags << tag.meta(property: 'og:type', content: meta_data[:og][:type]) if meta_data[:og][:type].present?
    tags << tag.meta(property: 'og:title', content: meta_data[:og][:title]) if meta_data[:og][:title].present?
    tags << tag.meta(property: 'og:description', content: meta_data[:og][:description]) if meta_data[:og][:description].present?
    tags << tag.meta(property: 'og:image', content: meta_data[:og][:image]) if meta_data[:og][:image].present?
    tags << tag.meta(property: 'og:url', content: canonical_url)

    # Twitter tags
    tags << tag.meta(name: 'twitter:card', content: 'summary_large_image')
    tags << tag.meta(name: 'twitter:title', content: meta_data[:twitter][:title]) if meta_data[:twitter][:title].present?
    tags << tag.meta(name: 'twitter:description', content: meta_data[:twitter][:description]) if meta_data[:twitter][:description].present?
    tags << tag.meta(name: 'twitter:image', content: meta_data[:twitter][:image]) if meta_data[:twitter][:image].present?

    # Canonical URL
    tags << tag.link(rel: 'canonical', href: canonical_url)

    safe_join(tags)
  end

  def canonical_url
    "#{HOST}#{request.path}"
  end
end