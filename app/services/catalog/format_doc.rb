# frozen_string_literal: true

module Catalog
  # The format doc of one resource, the partial the old detail page showed in its Docs tab
  # (app/views/resources/docs/<type>, some with sub-partials per resource), read as data. The
  # partial stays the only copy of the content: it is rendered with the old presenter and parsed.
  #
  # - `guide`: the whole doc as docs segments (Content::DocPage), for the Docs tab.
  # - `schemas`: the doc's column tables (a header row naming the column or field) and column
  #   lists (three or more items, each `<code>name</code>: description`), named by the heading
  #   above them, for the Data tab.
  # - `sample`: the doc's first code block, for the Data tab.
  #
  # A resource whose partial is missing or renders nothing has no format doc (nil).
  class FormatDoc
    Schema = Data.define(:name, :columns)
    Column = Data.define(:name, :type, :description)

    PRESENTER_CONTEXT = Struct.new(:params, :action_name)
    # Header cells of a column table and the column field each one holds.
    HEADERS = { 'column' => :name, 'field' => :name, 'type' => :type, 'description' => :description,
                'what it holds' => :description, }.freeze
    LIST_MINIMUM = 3
    CODE_BLOCK = 'tw-docs-code-block'
    LIST_ITEM = /\A(?<name>.+?)\s*(?::|\s[—–-]\s)\s*(?<description>.+)\z/m

    attr_reader :schemas

    def self.for(resource)
      html = render(resource)
      new(html) if html.present?
    end

    def self.render(resource)
      presenter = ResourcePresenter.new(PRESENTER_CONTEXT.new(ActionController::Parameters.new, 'detail'))
      presenter.set_resource(resource)
      partial = "resources/docs/#{presenter.preview_partial(resource)}"
      return unless ActionView::LookupContext.new(ActionController::Base.view_paths).exists?(partial, [], true)

      # A sub-partial the resource's content row points at may be missing too (no doc), and the
      # partial reads editor data: either leaves the page without a Docs tab, never a 500.
      Rails.error.handle(fallback: -> {}) do
        ResourcesController.render(partial:, locals: { resource: }, assigns: { presenter: })
      end
    end

    def initialize(html)
      fragment = normalize(Nokogiri::HTML5.fragment(html))
      @schemas = fragment.css('table').filter_map { |table| table_schema(table) } +
                 fragment.css('ul').filter_map { |list| list_schema(list) }
      @page = Content::DocPage.new(key: nil, kind: 'format', title: nil, description: nil, html: fragment.to_html,
                                   position: Content::DocPage::NO_POSITION,)
    end

    def guide
      @page.segments
    end

    def sample
      guide.find { |segment| segment.kind == 'code' }
    end

    private

    # The old markup in the shape Content::DocPage splits: each code block (`.docs-code`, or a
    # bare `pre`) as a `tw-docs-code-block` with its label, callouts as quotes, and the wrapper
    # divs taken away so the code blocks sit at the top level.
    def normalize(fragment)
      replace_code_blocks(fragment)
      fragment.css('.docs-callout').each { |callout| callout.name = 'blockquote' }
      fragment.css("div:not(.#{CODE_BLOCK})").each { |wrapper| wrapper.replace(wrapper.children) }
      fragment
    end

    def replace_code_blocks(fragment)
      document = fragment.document
      fragment.css('.docs-code').each do |block|
        label = block.at_css('.docs-code-header span')&.text&.squish
        block.replace(code_block(document, label, block.at_css('pre').text))
      end
      fragment.css('pre').each do |pre|
        pre.replace(code_block(document, nil, pre.text)) unless pre.parent.classes.include?(CODE_BLOCK)
      end
    end

    def code_block(document, label, code)
      document.create_element('div', class: CODE_BLOCK).tap do |block|
        block << document.create_element('span', label, class: 'tw-docs-code-language') if label.present?
        block << document.create_element('pre', code.strip)
      end
    end

    def table_schema(table)
      header, *rows = table.css('tr').map { |row| row.css('th, td').map { |cell| cell.text.squish } }
      fields = header.to_a.map { |cell| HEADERS[cell.downcase] }
      return unless fields.first == :name && rows.any?

      Schema.new(name: heading_above(table), columns: rows.map { |row| table_column(fields, row) })
    end

    def table_column(fields, row)
      Column.new(name: nil, type: nil, description: nil, **fields.zip(row).to_h.except(nil))
    end

    def list_schema(list)
      columns = list.css('> li').map { |item| list_column(item) }
      Schema.new(name: heading_above(list), columns:) if columns.size >= LIST_MINIMUM && columns.all?
    end

    # `<li><code>name</code>: description</li>`, or with a dash; nil for any other item.
    def list_column(item)
      code = item.children.find(&:present?)
      match = LIST_ITEM.match(item.text.squish)
      return unless code&.name == 'code' && match && match[:name].start_with?(code.text.squish)

      Column.new(name: match[:name], type: nil, description: match[:description])
    end

    def heading_above(node)
      node.xpath('preceding::*[self::h2 or self::h3 or self::h4][1]').first&.text&.squish
    end
  end
end
