# frozen_string_literal: true

module Catalog
  # The catalog fields no column holds, computed from the whole catalog when a page is read:
  # display name, script family, rendering, lifecycle status and replacement, the summary of a
  # resource without one, and the links between resources with their type. The rules are Catalog::Inference and Catalog::DisplayNames; this class loads their
  # facts and applies them in the order each needs the others.
  #
  # An editor overrides a value with a key in the resource's `meta_data` (OVERRIDES). A valid
  # override wins over the computed value, and the rules that read the field read the override.
  # An invalid one is ignored.
  #
  # The catalog is a few hundred rows over two databases. Each request reads its fingerprint
  # (`fingerprint`, one query per database) and uses the values this process last computed when
  # the fingerprint is the same; otherwise it loads the catalog in a fixed number of queries and
  # computes them again (DECISIONS.md). The resources themselves are loaded per request, only
  # when a caller asks for them or for links. A DownloadableResource reads its fields from
  # `current` (CatalogFields), so callers use `resource.status` and need not know about this class.
  class Derived
    SCRIPT_FAMILIES = ['madani', 'indopak', 'other'].freeze
    RENDERINGS = ['unicode_font', 'glyph_page', 'image', 'svg'].freeze
    STATUSES = ['stable', 'beta', 'legacy', 'superseded'].freeze
    RELATION_TYPES = ['requires', 'pairs_with'].freeze

    # Field => the `meta_data` key that overrides it.
    OVERRIDES = {
      display_name: 'display-name', script_family: 'script-family', rendering: 'rendering', status: 'status',
      superseded_by: 'superseded-by',
    }.freeze

    # `superseded_by_id` is the replacement's id or nil (CatalogFields#superseded_by finds it).
    Values = Struct.new(:display_name, :script_family, :rendering, :status, :superseded_by_id, keyword_init: true)
    DEFAULTS = Values.new(status: 'stable').freeze

    # A link between two resources (DownloadableResource). `id` is the row's id; a requires-link
    # the data implies but no row holds has none.
    Link = Data.define(:id, :source, :target, :relation_type) do
      def requires? = relation_type == 'requires'
    end

    # What the rules compute, as ids and strings, so one request's can serve the next: resource
    # id => Values, => summary and => tag names, each link as [row id, source id, target id,
    # relation type], and the ids of the resources links and replacements name.
    Snapshot = Data.define(:values, :summaries, :tags, :links, :referenced)

    # Holds one request's (or job's) catalog; Rails resets it between requests.
    class Current < ActiveSupport::CurrentAttributes
      attribute :catalog
    end

    # [fingerprint, Snapshot] last computed in this process.
    @latest = nil
    class << self
      attr_accessor :latest
    end

    def self.current
      Current.catalog ||= new
    end

    # Forgets the request's catalog, so the next read checks the fingerprint again.
    def self.reset
      Current.catalog = nil
    end

    # An editor's display name (the `display-name` key): a non-blank String, squished.
    def self.display_name_override(value)
      value.squish.presence if value.is_a?(String)
    end

    # The state of the rows the values are computed from, or nil inside a transaction that has
    # written (a second write there to a row it already wrote leaves `xmin` as it was). Per table,
    # the count and the sum of `xmin`, the transaction that wrote each row version, change with
    # any insert, update or delete, whether it sets `updated_at` or not. A download rewrites its
    # file's counters, so for files only the published (resource, file type) pairs count.
    def self.fingerprint
      tables = versions(DownloadableResource, DownloadableResourceTagging, DownloadableResourceTag,
                        DownloadableRelatedResource,)
      cms = ApplicationRecord.connection.select_rows(<<~SQL.squish).first
        SELECT txid_current_if_assigned(), #{tables},
          (SELECT md5(string_agg(downloadable_resource_id || '/' || coalesce(file_type, ''), ',' ORDER BY id))
           FROM downloadable_files WHERE published)
      SQL
      return if cms.first

      content = versions(ResourceContent, Language, Mushaf, Recitation, ::Audio::Recitation, RecitationStyle)
      cms.drop(1) + QulQuranRecord.connection.select_rows("SELECT #{content}").first
    end

    def self.versions(*models)
      models.map do |model|
        "(SELECT count(*) || ':' || coalesce(sum(xmin::text::bigint), 0) FROM #{model.quoted_table_name})"
      end.join(', ')
    end
    private_class_method :versions

    def initialize
      fingerprint = self.class.fingerprint
      latest = self.class.latest
      @snapshot = if fingerprint && latest&.first == fingerprint
                    latest.last
                  else
                    compute.tap { |snapshot| self.class.latest = [fingerprint, snapshot].freeze if fingerprint }
                  end
    end

    # The fields of a resource. One this catalog does not hold (a new record) has its name, the
    # default status and nothing else.
    def of(resource)
      @snapshot.values[resource.id] || DEFAULTS.dup.tap { |values| values.display_name = resource.name }
    end

    # One plain sentence for a resource with no summary of its own (Inference.summary).
    def summary(resource)
      @snapshot.summaries[resource.id]
    end

    # The names of the resource's tags.
    def tag_names(resource)
      @snapshot.tags.fetch(resource.id, [])
    end

    # The resource that replaces this one, or nil.
    def superseded_by(resource)
      of(resource).superseded_by_id&.then { |id| by_id[id] }
    end

    # Links the resource holds, and links other resources hold to it, in row order. A link with
    # a missing end is skipped, and so is a repeat of a pair (the oldest row counts).
    def links_from(resource) = links.select { |link| link.source.id == resource.id }
    def links_to(resource) = links.select { |link| link.target.id == resource.id }

    # The resources in id order, with their content rows and languages, loaded on first use.
    def resources
      @resources ||= load_resources
    end

    private

    # Without the resources loaded, only those that links and replacements name, as plain rows.
    def by_id
      @by_id ||= (@resources || DownloadableResource.where(id: @snapshot.referenced).order(:id).to_a).index_by(&:id)
    end

    def links
      @links ||= @snapshot.links.filter_map do |id, source, target, relation_type|
        next unless by_id.key?(source) && by_id.key?(target)

        Link.new(id: id, source: by_id[source], target: by_id[target], relation_type: relation_type)
      end
    end

    def compute # rubocop:disable Metrics/AbcSize -- the snapshot's parts, in the order they need each other
      @tags = DownloadableResourceTagging.joins(:downloadable_resource_tag).order(:id)
        .pluck(:downloadable_resource_id, 'downloadable_resource_tags.name')
        .group_by(&:first).transform_values { |rows| rows.map(&:last).freeze }
      @overrides = resources.to_h { |resource| [resource.id, overrides(resource)] }
      @names = DisplayNames.call(resources, @overrides.transform_values { |values| values[:display_name] }.compact)
      @rows = stored_links
      @facts = load_facts
      values = derive
      summaries = @facts.transform_values { |facts| Inference.summary(facts)&.freeze }
      links = link_rows
      referenced = (links.flat_map { |link| link[1, 2] } + values.values.filter_map(&:superseded_by_id)).uniq
      Snapshot.new(values: values.freeze, summaries: summaries.freeze, tags: @tags.freeze, links: links.freeze,
                   referenced: referenced.freeze,)
    end

    def load_resources
      DownloadableResource.order(:id)
        .preload(:language, resource_content: :language)
        .to_a
    end

    # [source id, target id, row id] of each usable link row.
    def stored_links
      DownloadableRelatedResource.order(:id).pluck(:downloadable_resource_id, :related_resource_id, :id)
        .select { |source, target, _| by_id.key?(source) && by_id.key?(target) }
        .uniq { |source, target, _| [source, target] }
    end

    def load_facts # rubocop:disable Metrics/AbcSize -- the facts' queries, each keyed by resource
      formats = DownloadableFile.where(published: true).pluck(:downloadable_resource_id, :file_type)
        .group_by(&:first).transform_values { |rows| rows.map(&:last) }
      mushafs = MushafLayouts::Page.mushafs_for(resources.select(&:mushaf_layout?))
      linked = @rows.group_by(&:first).transform_values { |rows| rows.map { |row| row[1] } }

      resources.to_h do |resource|
        fonts = linked.fetch(resource.id, []).select { |id| by_id[id].resource_type == 'font' }
        [resource.id, facts(resource, formats.fetch(resource.id, []), mushafs[resource.id], fonts)]
      end
    end

    def facts(resource, formats, mushaf, linked_fonts)
      content = resource.resource_content

      Inference::Facts.new(
        id: resource.id, type: resource.resource_type, type_label: Taxonomy.type(resource.resource_type)&.label,
        name: resource.name, cardinality: resource.cardinality_type, published: resource.published,
        language: (resource.language || content&.language)&.name&.split(',')&.first,
        tags: @tags.fetch(resource.id, []), formats: formats, requires: [],
        linked_fonts: linked_fonts, **script_facts(resource, content, mushaf),
      )
    end

    def script_facts(resource, content, mushaf) # rubocop:disable Metrics/AbcSize -- the meta keys of each type, side by side
      meta = ->(key) { content&.meta_value(key).presence }

      case resource.resource_type
      when 'quran-script'
        { text_types: [meta['text-type']].compact, font_codes: [meta['font'], meta['font-face']].compact }
      when 'mushaf-layout'
        { text_types: [meta['text-type']].compact, font_codes: [mushaf&.default_font_name].compact,
          mushaf: mushaf && Inference::Mushaf.new(font: mushaf.default_font_name, pages: mushaf.pages_count,
                                                  lines: mushaf.lines_per_page,), }
      when 'font'
        { text_types: [resource.meta_value('script'), meta['script']].compact_blank,
          font_codes: [resource.meta_value('font-face'), meta['font-face'], meta['font-path']].compact_blank,
          per_page: Fonts::UrlResolver::FORMATS.keys.any? { |format| File.basename(meta[format].to_s) == format },
          svg: meta['svg-template'].present?, }
      else
        { text_types: [], font_codes: [] }
      end
    end

    # Each rule reads what the rules before it set on the facts, so the order matters: script
    # family and rendering, then status, then the required font.
    def derive # rubocop:disable Metrics/AbcSize -- the rules in the order they depend on each other
      catalog = @facts.values
      catalog.each do |facts|
        override = @overrides[facts.id]
        facts.script_family = override[:script_family] || Inference.script_family(facts)
        facts.rendering = override[:rendering] || Inference.rendering(facts)
      end
      replacements = catalog.to_h { |facts| [facts.id, lifecycle(facts, catalog)] }
      fonts = catalog.select { |facts| facts.type == 'font' }
      catalog.each { |facts| facts.requires = [Inference.required_font(facts, fonts)].compact }

      catalog.to_h do |facts|
        [facts.id, Values.new(
          display_name: @names.fetch(facts.id), script_family: facts.script_family, rendering: facts.rendering,
          status: facts.status, superseded_by_id: replacements[facts.id]&.id,
        ).freeze,]
      end
    end

    # Sets the status on the facts and returns the replacement (a resource) or nil. A status
    # override wins; a replacement override alone makes the resource superseded.
    def lifecycle(facts, catalog)
      override = @overrides[facts.id]
      inferred, inferred_by = Inference.status(facts, catalog)
      facts.status = override[:status] || ('superseded' if override[:superseded_by]) || inferred || 'stable'

      override[:superseded_by] || (by_id[inferred_by] if facts.status == 'superseded')
    end

    # [row id, source id, target id, relation type] of each link: the usable rows, then the
    # requires-links the data implies that no row holds.
    def link_rows
      requires = @facts.transform_values { |facts| facts.requires.first }.compact
      stored = @rows.map do |source, target, id|
        [id, source, target, requires[source] == target ? 'requires' : 'pairs_with']
      end
      implied = requires.to_a - @rows.map { |row| row.first(2) }
      stored + implied.map { |source, target| [nil, source, target, 'requires'] }
    end

    # The valid overrides of a resource: field => value.
    def overrides(resource)
      return {} if resource.meta_data.blank?

      OVERRIDES.to_h { |field, key| [field, override(field, resource.meta_value(key), resource)] }.compact
    end

    def override(field, value, resource)
      case field
      when :display_name then self.class.display_name_override(value)
      when :script_family then choice(value, SCRIPT_FAMILIES)
      when :rendering then choice(value, RENDERINGS)
      when :status then choice(value, STATUSES)
      when :superseded_by then other_resource(value, resource)
      end
    end

    def choice(value, allowed)
      key = value.to_s.strip.downcase.tr('- ', '__')
      key if allowed.include?(key)
    end

    # Another resource, named by slug or id.
    def other_resource(value, resource)
      name = value.to_s.strip
      return if name.empty?

      @by_slug ||= resources.select { |other| other.slug.present? }.index_by(&:slug)
      found = @by_slug[name] || (by_id[name.to_i] if name.match?(/\A\d+\z/))
      found unless found&.id == resource.id
    end
  end
end
