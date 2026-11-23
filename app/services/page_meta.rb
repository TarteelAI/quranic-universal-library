# frozen_string_literal: true

# The server-managed head of an Inertia page: title, description, robots, Open Graph and
# Twitter tags, the canonical link and a JSON-LD script, in the format `render inertia: …, meta:`
# takes. The tags are in the HTML with or without SSR. The canonical host is the production host
# (SeoHelper::HOST), as on the old pages.
class PageMeta
  SITE_NAME = 'Quranic Universal Library'
  IMAGE = 'https://static-cdn.tarteel.ai/qul/og.jpeg'

  def initialize(title:, path:, description: nil, robots: 'index, follow', json_ld: nil)
    @title = title
    @description = description
    @url = "#{SeoHelper::HOST}#{path}"
    @robots = robots
    @json_ld = json_ld
  end

  def tags
    [
      { title: @title },
      { name: 'description', content: @description },
      { name: 'robots', content: @robots },
      { tag_name: 'link', rel: 'canonical', href: @url },
      { property: 'og:site_name', content: SITE_NAME },
      { property: 'og:type', content: 'website' },
      { property: 'og:title', content: @title },
      { property: 'og:description', content: @description },
      { property: 'og:url', content: @url },
      { property: 'og:image', content: IMAGE },
      { property: 'og:locale', content: 'en_US' },
      { name: 'twitter:card', content: 'summary_large_image' },
      { name: 'twitter:site', content: '@TarteelAI' },
      { name: 'twitter:title', content: @title },
      { name: 'twitter:description', content: @description },
      { name: 'twitter:image', content: IMAGE },
      json_ld_tag
    ].compact.reject { |tag| tag.key?(:content) && tag[:content].blank? }
  end

  private

  def json_ld_tag
    return unless @json_ld

    {
      tag_name: 'script',
      type: 'application/ld+json',
      inner_content: { '@context': 'https://schema.org', url: @url, name: @title, description: @description }
        .compact.merge(@json_ld)
    }
  end
end
