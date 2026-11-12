# frozen_string_literal: true

module Content
  # A docs page under /docs/:key for the new pages, resolved as the old page resolves it: a
  # markdown page (DocsPageService, app/views/docs/markdown) or else a resource tag
  # (DownloadableResourceTag). Keys backed only by an ERB partial under app/views/docs are help
  # dialog text and stay on the old page (Content::DocsRequest).
  #
  # The body is a list of segments: prose as HTML, code blocks and runnable examples as plain
  # text, so the page renders code itself and runs examples in its own sandboxed frame. Prose is
  # reduced to PROSE_TAGS with `href` and `title` only; the headings then get ids, and the h2 and
  # h3 headings are the contents list.
  class DocPage
    Segment = Data.define(:kind, :html, :language, :label, :code)
    Heading = Data.define(:id, :text, :level)
    Link = Data.define(:key, :title)
    Position = Data.define(:category, :previous, :next)

    PROSE_TAGS = %w[
      h1 h2 h3 h4 h5 h6 p br hr ul ol li pre code blockquote strong em b i u a
      table thead tbody tr th td
    ].freeze
    PROSE_ATTRIBUTES = %w[href title].freeze
    CONTENTS_LEVELS = [2, 3].freeze
    NO_POSITION = Position.new(category: nil, previous: nil, next: nil)

    attr_reader :key, :kind, :title, :description, :segments, :contents, :position

    def self.find(key)
      if (page = DocsPageService.new.find(key))
        from_markdown(page)
      elsif (tag = DownloadableResourceTag.find_by(slug: key))
        from_tag(tag)
      end
    end

    def self.from_markdown(page)
      new(key: page.slug, kind: 'page', title: page.title, description: page.description, html: page.html,
          position: position(page.slug))
    end

    # A tag page holds what the old one holds: the editor's description, the glossary link and
    # the tagged resources by type, under the old headings. Only published resources are listed.
    def self.from_tag(tag)
      description = Rails::HTML5::FullSanitizer.new.sanitize(tag.description.to_s).squish
      new(key: tag.slug, kind: 'tag', title: tag.name, description: description.truncate(160, separator: ' ').presence,
          html: TagBody.new(tag).html, position: NO_POSITION)
    end

    def self.position(key)
      pages = DocsManifest.pages_in_order
      index = pages.index { |page| page.slug == key }
      return NO_POSITION unless index

      category = DocsManifest.category_for_page(key)
      Position.new(
        category: Link.new(key: category.slug, title: category.title),
        previous: (link(pages[index - 1]) if index.positive?),
        next: link(pages[index + 1])
      )
    end

    def self.link(page)
      Link.new(key: page.slug, title: page.title) if page
    end

    def initialize(key:, kind:, title:, description:, html:, position:)
      @key = key
      @kind = kind
      @title = title
      @description = description
      @position = position
      @ids = Hash.new(0)
      @contents = []
      @segments = split(html)
    end

    private

    # DocsPageService wraps each fenced block in a div: `tw-docs-code-block` (a pre with its
    # language label) or `tw-docs-playground` (a textarea with the example's code).
    def split(html)
      segments = []
      prose = +''
      Nokogiri::HTML5.fragment(html).children.each do |node|
        segment = code_segment(node)
        if segment
          segments << prose_segment(prose) if prose.present?
          segments << segment
          prose = +''
        else
          prose << node.to_html
        end
      end
      segments << prose_segment(prose) if prose.present?
      segments
    end

    def code_segment(node)
      return unless node.element? && node.name == 'div'

      if node.classes.include?('tw-docs-playground')
        Segment.new(kind: 'playground', html: nil, language: 'javascript', label: 'JavaScript',
                    code: node.at_css('textarea').text)
      elsif node.classes.include?('tw-docs-code-block')
        code = node.at_css('pre code') || node.at_css('pre')
        language = code['class'].to_s[/\blanguage-(\S+)/, 1]
        Segment.new(kind: 'code', html: nil, language:, label: node.at_css('.tw-docs-code-language')&.text,
                    code: code.text)
      end
    end

    def prose_segment(html)
      clean = Rails::HTML5::SafeListSanitizer.new.sanitize(html, tags: PROSE_TAGS, attributes: PROSE_ATTRIBUTES)
      fragment = Nokogiri::HTML5.fragment(clean)
      fragment.css('h1, h2, h3, h4, h5, h6').each { |heading| anchor(heading) }
      Segment.new(kind: 'html', html: fragment.to_html, language: nil, label: nil, code: nil)
    end

    def anchor(heading)
      text = heading.text.squish
      base = text.parameterize.presence || 'section'
      @ids[base] += 1
      heading['id'] = @ids[base] == 1 ? base : "#{base}-#{@ids[base]}"
      level = heading.name.delete_prefix('h').to_i
      @contents << Heading.new(id: heading['id'], text:, level:) if CONTENTS_LEVELS.include?(level)
    end

    # The tag page's HTML: the editor's description reduced to prose (so it can hold no code
    # segment), then the glossary link and the tagged resources, built and escaped here.
    class TagBody
      delegate :tag, :link_to, :safe_join, to: 'ActionController::Base.helpers'
      delegate :catalog_resource_path, to: 'Rails.application.routes.url_helpers'

      GLOSSARY = 'https://www.tarteel.ai/glossary'

      def initialize(tag)
        @tag = tag
      end

      def html
        description = Rails::HTML5::SafeListSanitizer.new.sanitize(@tag.description.to_s, tags: PROSE_TAGS,
                                                                                          attributes: PROSE_ATTRIBUTES)
        [description, glossary, related].join
      end

      private

      def glossary
        return if @tag.glossary_term.blank?

        tag.p(safe_join(['Read more about ', link_to(@tag.name, "#{GLOSSARY}/#{@tag.glossary_term}"),
                         ' in the ', link_to('Tarteel glossary', GLOSSARY), '.']))
      end

      # Groups in catalog order, resources by name (the catalog's display name).
      def related
        resources = @tag.downloadable_resources.published.to_a
        return if resources.empty?

        order = Catalog::Taxonomy.types.map(&:key)
        groups = resources.group_by(&:resource_type).sort_by { |type, _| order.index(type) || order.size }
        sections = groups.map do |_type, rows|
          items = rows.sort_by(&:display_name).map do |row|
            tag.li(link_to(row.display_name, catalog_resource_path(row.resource_type, row.to_param)))
          end
          safe_join([tag.h3(rows.first.group_name), tag.ul(safe_join(items))])
        end
        safe_join([tag.h2(safe_join(['Resources related to ', tag.strong(@tag.name), ' tag'])), *sections])
      end
    end
  end
end
