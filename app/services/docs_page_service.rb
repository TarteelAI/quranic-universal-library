require "redcarpet"
require "uri"
require "nokogiri"

class DocsPageService
  Page = Struct.new(:slug, :title, :html, keyword_init: true)

  DOCS_DIR = Rails.root.join("docs").freeze
  SLUG_PATTERN = /\A[a-z0-9][a-z0-9-]*\z/
  ALLOWED_TAGS = %w[
    h1 h2 h3 h4 h5 h6 p br hr ul ol li pre code blockquote strong em a table thead tbody tr th td
    div span button textarea iframe
  ].freeze
  ALLOWED_ATTRIBUTES = %w[
    href title class rel target type aria-label sandbox
    data-controller data-action data-docs-code-target data-docs-code-language-value data-docs-code-playground-value
  ].freeze
  PLAYGROUND_LANGUAGE = "playground-js".freeze

  def initialize
    @markdown = Redcarpet::Markdown.new(
      Redcarpet::Render::HTML.new(filter_html: true, hard_wrap: true),
      autolink: true,
      fenced_code_blocks: true,
      no_intra_emphasis: true,
      strikethrough: true,
      tables: true
    )
    @sanitizer = Rails::Html::SafeListSanitizer.new
  end

  def readme
    render_file("README.md", slug: "index")
  end

  def find(slug)
    return nil unless valid_slug?(slug)

    render_file("#{slug}.md", slug: slug)
  end

  private

  def render_file(filename, slug:)
    path = resolve_path(filename)
    return nil unless path&.file?

    markdown = path.read
    html = @markdown.render(markdown)
    html = rewrite_internal_links(html)
    html = decorate_code_blocks(html)
    html = @sanitizer.sanitize(html, tags: ALLOWED_TAGS, attributes: ALLOWED_ATTRIBUTES)

    Page.new(
      slug: slug,
      title: extract_title(markdown, slug),
      html: html
    )
  rescue Errno::ENOENT
    nil
  end

  def resolve_path(filename)
    docs_root = DOCS_DIR.expand_path
    candidate = docs_root.join(filename).cleanpath
    docs_root_prefix = "#{docs_root}/"
    return nil unless candidate.extname == ".md"
    return nil unless candidate.to_s.start_with?(docs_root_prefix)

    candidate
  end

  def valid_slug?(slug)
    slug.is_a?(String) && slug.match?(SLUG_PATTERN)
  end

  def extract_title(markdown, slug)
    heading = markdown.each_line.find { |line| line.start_with?("# ") }
    return heading.sub("# ", "").strip if heading.present?

    slug.to_s.humanize
  end

  def rewrite_internal_links(html)
    fragment = Nokogiri::HTML.fragment(html)
    fragment.css("a[href]").each do |link|
      href = link["href"].to_s.strip
      link["href"] = rewrite_href(href)
    end
    fragment.to_html
  end

  def decorate_code_blocks(html)
    fragment = Nokogiri::HTML.fragment(html)
    fragment.css("pre > code").each do |code_node|
      pre_node = code_node.parent
      next unless pre_node

      language = extract_code_language(code_node["class"])
      if language == PLAYGROUND_LANGUAGE
        pre_node.replace(build_playground_block(fragment, code_node.text))
      else
        pre_node.replace(build_code_block(fragment, pre_node, language))
      end
    end
    fragment.to_html
  end

  def build_code_block(fragment, pre_node, language)
    normalized_language = normalize_code_language(language)
    cloned_pre = pre_node.dup(1)
    cloned_pre["data-docs-code-target"] = "code"
    cloned_code = cloned_pre.at_css("code")
    if cloned_code && normalized_language != "text"
      cloned_code["class"] = "language-#{normalized_language}"
    end

    wrapper = Nokogiri::XML::Node.new("div", fragment)
    wrapper["class"] = "tw-docs-code-block"
    wrapper["data-controller"] = "docs-code"
    wrapper.add_child(build_code_header(fragment, display_language(normalized_language), copy_only: true))
    wrapper.add_child(cloned_pre)
    wrapper
  end

  def build_playground_block(fragment, code_text)
    wrapper = Nokogiri::XML::Node.new("div", fragment)
    wrapper["class"] = "tw-docs-playground"
    wrapper["data-controller"] = "docs-code"
    wrapper["data-docs-code-playground-value"] = "true"
    wrapper["data-docs-code-language-value"] = "javascript"
    wrapper.add_child(build_code_header(fragment, "JavaScript Playground", copy_only: false))

    grid = Nokogiri::XML::Node.new("div", fragment)
    grid["class"] = "tw-docs-playground-grid"

    editor_pane = Nokogiri::XML::Node.new("div", fragment)
    editor_pane["class"] = "tw-docs-playground-pane"
    editor_pane.add_child(build_playground_label(fragment, "Editor"))

    editor = Nokogiri::XML::Node.new("textarea", fragment)
    editor["class"] = "tw-docs-playground-editor"
    editor["data-docs-code-target"] = "editor"
    editor.content = code_text
    editor_pane.add_child(editor)

    preview_pane = Nokogiri::XML::Node.new("div", fragment)
    preview_pane["class"] = "tw-docs-playground-pane"
    preview_pane.add_child(build_playground_label(fragment, "Preview"))

    preview = Nokogiri::XML::Node.new("iframe", fragment)
    preview["class"] = "tw-docs-playground-preview"
    preview["title"] = "Code preview"
    preview["sandbox"] = "allow-scripts"
    preview["data-docs-code-target"] = "preview"
    preview_pane.add_child(preview)

    grid.add_child(editor_pane)
    grid.add_child(preview_pane)
    wrapper.add_child(grid)
    wrapper
  end

  def build_code_header(fragment, language_label, copy_only:)
    header = Nokogiri::XML::Node.new("div", fragment)
    header["class"] = "tw-docs-code-header"

    language = Nokogiri::XML::Node.new("span", fragment)
    language["class"] = "tw-docs-code-language"
    language.content = language_label
    header.add_child(language)

    actions = Nokogiri::XML::Node.new("div", fragment)
    actions["class"] = "tw-docs-code-actions"
    actions.add_child(build_code_button(fragment, "Copy", "docs-code#copy", "copyButton"))

    unless copy_only
      actions.add_child(build_code_button(fragment, "Run", "docs-code#run"))
      actions.add_child(build_code_button(fragment, "Reset", "docs-code#reset"))
    end

    header.add_child(actions)
    header
  end

  def build_code_button(fragment, text, action, target = nil)
    button = Nokogiri::XML::Node.new("button", fragment)
    button["type"] = "button"
    button["class"] = "tw-docs-code-button"
    button["data-action"] = action
    button["data-docs-code-target"] = target if target.present?
    button.content = text
    button
  end

  def build_playground_label(fragment, text)
    label = Nokogiri::XML::Node.new("div", fragment)
    label["class"] = "tw-docs-playground-label"
    label.content = text
    label
  end

  def extract_code_language(class_name)
    return "text" if class_name.blank?

    tokens = class_name.to_s.split(/\s+/)
    explicit = tokens.find { |token| token.start_with?("language-") }
    language = explicit ? explicit.delete_prefix("language-") : tokens.first
    language.to_s.downcase
  end

  def normalize_code_language(language)
    case language.to_s.downcase
    when "", "plain", "plaintext"
      "text"
    when "js", "node"
      "javascript"
    when "shell", "sh", "zsh"
      "bash"
    else
      language.to_s.downcase
    end
  end

  def display_language(language)
    case language
    when "javascript"
      "JavaScript"
    when "python"
      "Python"
    when "ruby"
      "Ruby"
    when "bash"
      "Shell"
    when "json"
      "JSON"
    when "sql"
      "SQL"
    else
      language.to_s.titleize
    end
  end

  def rewrite_href(href)
    return href if href.blank? || href.start_with?("#")

    begin
      uri = URI.parse(href)
      return href if uri.scheme.present? || uri.host.present?
    rescue URI::InvalidURIError
      return href
    end

    path_part = href.split(/[?#]/, 2).first.to_s
    suffix = href.delete_prefix(path_part)
    normalized = path_part.sub(%r{\A\./}, "").sub(%r{\Adocs/}, "")

    return href unless normalized.end_with?(".md")

    slug = normalized.delete_suffix(".md")
    return "/docs#{suffix}" if slug.casecmp("README").zero? || slug.blank?
    return href unless valid_slug?(slug)

    "/docs/#{slug}#{suffix}"
  end
end
