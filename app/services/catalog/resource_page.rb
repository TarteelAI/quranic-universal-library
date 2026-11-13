# frozen_string_literal: true

module Catalog
  # What the detail page of one published resource shows: its files with their download facts,
  # why a restricted resource cannot be downloaded, the resources it works with, the data facts,
  # the licence, the changelog and the issue link. It knows nothing of the request or the session:
  # the caller passes the signed-in user, who may be allowed to download a restricted resource.
  #
  # The CMS rows (files, links, permission, changelog) and the content rows (resource content,
  # language, mushaf) are in separate databases and are loaded in separate queries.
  class ResourcePage
    Download = Data.define(:id, :name, :format, :format_label, :byte_size, :md5) # rubocop:disable Naming/VariableNumber -- md5 is the prop name
    Fact = Data.define(:label, :value)
    Link = Data.define(:resource, :reviewed)
    Group = Data.define(:key, :label, :links)
    Licence = Data.define(:name, :url, :summary)
    Change = Data.define(:id, :title, :excerpt, :date)

    TABS = ['preview', 'data', 'docs', 'licence', 'changelog'].freeze

    # Relation groups of "Works with", in this order. A link is listed from the resource that
    # holds it (`from`) or, for links that read the same both ways, from either end.
    GROUPS = [
      { key: 'requires', label: 'Requires', relation: 'requires', from: :self },
      { key: 'required_by', label: 'Needed by', relation: 'requires', from: :other },
      { key: 'pairs_with', label: 'Pairs with', relation: 'pairs_with', from: :either },
      { key: 'alternative', label: 'Alternatives', relation: 'alternative', from: :either },
      { key: 'supersedes', label: 'Replaces', relation: 'supersedes', from: :self },
    ].freeze

    ISSUE_FORM = "#{SiteNav::REPO_URL}/issues/new".freeze

    # Editor HTML (resource info, copyright notices) is reduced to these before it becomes a prop.
    HTML_TAGS = [
      'p', 'br', 'strong', 'em', 'b', 'i', 'u', 'ul', 'ol', 'li', 'a', 'h3', 'h4', 'h5', 'h6', 'blockquote', 'code',
    ].freeze
    HTML_ATTRIBUTES = ['href'].freeze

    DATE_FORMAT = '%-d %B %Y'

    attr_reader :resource, :type

    def self.sanitize(html)
      return if html.blank?

      Rails::HTML5::SafeListSanitizer.new.sanitize(html, tags: HTML_TAGS, attributes: HTML_ATTRIBUTES).strip.presence
    end

    # `viewer` is the signed-in user or nil.
    def initialize(resource, viewer:)
      @resource = resource
      @type = Taxonomy.type(resource.resource_type)
      @viewer = viewer
    end

    # Restricted resources are downloaded by admins only (Catalog::DownloadsController too).
    def self.download_allowed?(resource, user)
      !resource.restrict_download? || user&.is_admin? || user&.is_super_admin? || false
    end

    def self.find(param)
      DownloadableResource.published # rubocop:disable Rails/DynamicFindBy -- find_by_slug_or_id! is our own finder
        .preload(:language, :superseded_by, :downloadable_resource_tags,
                 resource_content: :language,
                 downloadable_related_resources: :related_resource,)
        .find_by_slug_or_id!(param)
    end

    def files
      @files ||= published_files.map do |file|
        blob = file.file.blob
        format = Taxonomy.format_for(file.file_type)
        Download.new(id: file.id, name: file.file_type.to_s.strip, format:,
                     format_label: Taxonomy.label(Taxonomy.formats, format), byte_size: blob.byte_size,
                     md5: Base64.decode64(blob.checksum.to_s).unpack1('H*'),) # rubocop:disable Naming/VariableNumber
      end
    end

    def can_download?
      self.class.download_allowed?(resource, @viewer)
    end

    # Why a restricted resource cannot be downloaded: the copyright notice its permission row
    # holds, as sanitized HTML, or a general sentence.
    def restriction
      return unless resource.restrict_download?

      self.class.sanitize(resource.resource_content&.resource_permission&.copyright_notice) ||
        'The publisher allows this resource to be viewed here but not downloaded. Ask them for permission to use it.'
    end

    def summary
      resource.short_summary.presence || type.summary
    end

    # The content row's export version (a unix time, which the asset manifest and the CDN file
    # names use as the version), or nil.
    def version
      exported = resource.resource_content&.meta_value('exported-version').to_s
      exported if exported.match?(/\A\d+\z/)
    end

    # The date of the export version where there is one, else of the newest file.
    def updated_on
      time = Time.zone.at(version.to_i) if version
      time ||= published_files.filter_map { |file| file.file.blob.created_at }.max
      time&.to_date
    end

    # The format doc of the old Docs tab (Catalog::FormatDoc), or nil.
    def format_doc
      return @format_doc if defined?(@format_doc)

      @format_doc = FormatDoc.for(resource)
    end

    def works_with
      outgoing = published_outgoing_links
      incoming = published_incoming_links

      GROUPS.filter_map do |group|
        links = group_links(group, outgoing, incoming)
        Group.new(key: group[:key], label: group[:label], links:) if links.any?
      end
    end

    def facts # rubocop:disable Metrics/AbcSize -- one list of facts, in display order
      [
        Fact.new(label: 'Type', value: type.label),
        Fact.new(label: 'Granularity', value: resource.humanize_cardinality_type),
        Fact.new(label: 'Language', value: language),
        Fact.new(label: 'Script family', value: Taxonomy.label(Taxonomy.script_families, resource.script_family)),
        Fact.new(label: 'Rendering', value: Taxonomy.label(Taxonomy.renderings, resource.rendering)),
        *layout_facts,
        Fact.new(label: 'Formats', value: files.map(&:format_label).uniq.join(', ')),
        Fact.new(label: 'Files', value: files.size.to_s),
        Fact.new(label: 'Updated', value: updated_on&.strftime(DATE_FORMAT)),
        Fact.new(label: 'Tags', value: resource.tag_names.sort_by(&:downcase).join(', ')),
      ].select { |fact| fact.value.present? }
    end

    def guide_path
      Taxonomy.guide_path(resource.resource_type)
    end

    def licence
      licence = resource.resource_content&.resource_permission&.licence
      Licence.new(name: licence.display_name, url: licence.url.presence, summary: licence.summary.presence) if licence
    end

    def changelog
      return [] unless resource.resource_content_id

      @changelog ||= ChangeLog.published.where(resource_content_id: resource.resource_content_id).latest
        .map do |change|
        Change.new(id: change.id, title: change.title, excerpt: change.excerpt, date: change.created_at.to_date)
      end
    end

    # The tab to show: a known tab the page has, else the preview.
    def tab(key)
      tabs = TABS - (changelog.empty? ? ['changelog'] : []) - (format_doc ? [] : ['docs'])
      tabs.include?(key) ? key : 'preview'
    end

    # The content issue form with the resource named, or the form chooser for a type the form's
    # dropdown lacks. `url` is the page's public URL.
    def issue_url(url)
      fields = { resource_name: resource.display_name, resource_link: url }
      option = Taxonomy::ISSUE_TYPES[resource.resource_type]
      return "#{ISSUE_FORM}/choose?#{fields.to_query}" unless option

      "#{ISSUE_FORM}?#{{ template: 'content_issue.yml', resource_type: option, **fields }.to_query}"
    end

    private

    def published_files
      @published_files ||= resource.downloadable_files.where(published: true).with_attached_file
        .order(:position, :id).select { |file| file.file.attached? }
    end

    def published_outgoing_links
      resource.downloadable_related_resources.select { |link| link.related_resource&.published }.sort_by(&:id)
    end

    def published_incoming_links
      DownloadableRelatedResource.where(related_resource_id: resource.id)
        .preload(:downloadable_resource).to_a
        .select { |link| link.downloadable_resource&.published }
    end

    def group_links(group, outgoing, incoming)
      mine = linked(outgoing, group[:relation], &:related_resource)
      theirs = linked(incoming, group[:relation], &:downloadable_resource)
      { self: mine, other: theirs, either: mine + theirs }.fetch(group[:from]).uniq { |link| link.resource.id }
    end

    def linked(links, relation)
      links.select { |link| link.relation_type == relation }
        .map { |link| Link.new(resource: yield(link), reviewed: reviewed?(link)) }
    end

    def reviewed?(link)
      link.downloadable_resource.reviewed?("link:#{link.related_resource_id}")
    end

    def language
      (resource.language || resource.resource_content&.language)&.name
    end

    def layout_facts
      return [] unless resource.mushaf_layout?

      mushaf = MushafLayouts::Page.mushaf_for(resource)
      [Fact.new(label: 'Pages', value: mushaf&.pages_count&.to_s),
       Fact.new(label: 'Lines per page', value: mushaf&.lines_per_page&.to_s),]
    end
  end
end
