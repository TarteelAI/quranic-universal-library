# frozen_string_literal: true

module Content
  # What the docs search matches in the browser: every page of config/docs.yml in reading order,
  # with its title, category, contents list (Content::DocPage) and prose as plain text. Code
  # blocks and runnable examples are not prose and are left out.
  module DocsSearchIndex
    Entry = Data.define(:key, :title, :category, :headings, :text)

    def self.entries
      DocsManifest.pages_in_order.filter_map do |page|
        doc = DocPage.find(page.slug) or next
        Entry.new(key: doc.key, title: doc.title, category: doc.position.category&.title, headings: doc.contents,
                  text: prose(doc),)
      end
    end

    # The prose without its headings, which are the title and the contents list.
    def self.prose(doc)
      doc.segments.select { |segment| segment.kind == 'html' }.map do |segment|
        fragment = Nokogiri::HTML5.fragment(segment.html)
        fragment.css('h1, h2, h3, h4, h5, h6').each(&:remove)
        fragment.text
      end.join(' ').squish
    end
  end
end
