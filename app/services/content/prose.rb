# frozen_string_literal: true

module Content
  # Editor-entered HTML (FAQ answers, credits entries) reduced to the docs prose tags with `href`
  # and `title` only, so no script, frame, image or event-handler attribute reaches the page.
  # Scripts and styles go with their text, which would otherwise show as prose.
  module Prose
    def self.sanitize(html)
      fragment = Nokogiri::HTML5.fragment(html.to_s)
      fragment.css('script, style').remove
      Rails::HTML5::SafeListSanitizer.new.sanitize(fragment.to_html, tags: DocPage::PROSE_TAGS,
                                                                     attributes: DocPage::PROSE_ATTRIBUTES,)
    end
  end
end
