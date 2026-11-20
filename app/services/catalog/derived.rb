# frozen_string_literal: true

module Catalog
  # The catalog fields no column holds, computed from the whole catalog when a page is read:
  # display name, script family, rendering, lifecycle status and replacement, the recommended
  # flag, the summary of a resource without one, and the links between resources with their
  # type. The rules are Catalog::Inference and Catalog::DisplayNames; this class loads their
  # facts and applies them in the order each needs the others.
  #
  # An editor overrides a value with a key in the resource's `meta_data` (OVERRIDES). A valid
  # override wins over the computed value, and the rules that read the field read the override.
  # An invalid one is ignored.
  #
  # The catalog is a few hundred rows over two databases. It is loaded once per request in a
  # fixed number of queries (`current`), whatever the number of resources a page shows, and
  # nothing is kept between requests. A DownloadableResource reads its fields from `current`
  # (CatalogFields), so callers use `resource.status` and need not know about this class.
  class Derived
    SCRIPT_FAMILIES = ['madani', 'indopak', 'other'].freeze
    RENDERINGS = ['unicode_font', 'glyph_page', 'image', 'svg'].freeze
    STATUSES = ['stable', 'beta', 'legacy', 'superseded'].freeze
    RELATION_TYPES = ['requires', 'pairs_with'].freeze

    # Field => the `meta_data` key that overrides it.
    OVERRIDES = {
      display_name: 'display-name', script_family: 'script-family', rendering: 'rendering', status: 'status',
      superseded_by: 'superseded-by', recommended: 'recommended',
    }.freeze

    # `superseded_by` is a DownloadableResource or nil.
    Values = Struct.new(:display_name, :script_family, :rendering, :status, :superseded_by, :recommended,
                        keyword_init: true,)
    DEFAULTS = Values.new(status: 'stable', recommended: false).freeze

    # A link between two resources (DownloadableResource). `id` is the row's id; a requires-link
    # the data implies but no row holds has none.
    Link = Data.define(:id, :source, :target, :relation_type) do
      def requires? = relation_type == 'requires'
    end

    # Holds one request's (or job's) catalog; Rails resets it between requests.
    class Current < ActiveSupport::CurrentAttributes
      attribute :catalog
    end

    def self.current
      Current.catalog ||= new
    end

    # Forgets the loaded catalog, so the next read sees rows changed since.
    def self.reset
      Current.catalog = nil
    end

    def initialize
      @resources = load_resources
      @by_id = @resources.index_by(&:id)
      @overrides = @resources.to_h { |resource| [resource.id, overrides(resource)] }
      @names = DisplayNames.call(@resources, @overrides.transform_values { |values| values[:display_name] }.compact)
      @rows = stored_links
      @facts = load_facts
      @values = derive
    end

    # The fields of a resource. One this catalog does not hold (a new record) has its name, the
    # default status and nothing else.
    def of(resource)
      @values[resource.id] || DEFAULTS.dup.tap { |values| values.display_name = resource.name }
    end

    # One plain sentence for a resource with no summary of its own (Inference.summary).
    def summary(resource)
      facts = @facts[resource.id]
      Inference.summary(facts) if facts
    end

    # Links the resource holds, and links other resources hold to it, in row order. A link with
    # a missing end is skipped, and so is a repeat of a pair (the oldest row counts).
    def links_from(resource) = links.select { |link| link.source.id == resource.id }
    def links_to(resource) = links.select { |link| link.target.id == resource.id }

    # The resources in id order, as loaded here (with their content rows and tags).
    attr_reader :resources

    private

    def load_resources
      DownloadableResource.order(:id)
        .preload(:downloadable_resource_tags, :language, resource_content: :language)
        .to_a
    end

    # [source id, target id, row id] of each usable link row.
    def stored_links
      DownloadableRelatedResource.order(:id).pluck(:downloadable_resource_id, :related_resource_id, :id)
        .select { |source, target, _| @by_id.key?(source) && @by_id.key?(target) }
        .uniq { |source, target, _| [source, target] }
    end

    def load_facts # rubocop:disable Metrics/AbcSize -- the facts' queries, each keyed by resource
      formats = DownloadableFile.where(published: true).pluck(:downloadable_resource_id, :file_type)
        .group_by(&:first).transform_values { |rows| rows.map(&:last) }
      mushafs = MushafLayouts::Page.mushafs_for(@resources.select(&:mushaf_layout?))
      linked = @rows.group_by(&:first).transform_values { |rows| rows.map { |row| row[1] } }

      @resources.to_h do |resource|
        fonts = linked.fetch(resource.id, []).select { |id| @by_id[id].resource_type == 'font' }
        [resource.id, facts(resource, formats.fetch(resource.id, []), mushafs[resource.id], fonts)]
      end
    end

    def facts(resource, formats, mushaf, linked_fonts) # rubocop:disable Metrics/AbcSize -- one struct, field by field
      content = resource.resource_content

      Inference::Facts.new(
        id: resource.id, type: resource.resource_type, type_label: Taxonomy.type(resource.resource_type)&.label,
        name: resource.name, cardinality: resource.cardinality_type, published: resource.published,
        recommended_by_person: @overrides[resource.id][:recommended],
        language: (resource.language || content&.language)&.name&.split(',')&.first,
        tags: resource.downloadable_resource_tags.map(&:name), formats: formats, requires: [],
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
          mushaf: mushaf && Inference::Mushaf.new(font: mushaf.default_font_name, default: mushaf.is_default,
                                                  pages: mushaf.pages_count, lines: mushaf.lines_per_page,), }
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
    # family and rendering, then status, then the required font, then the recommended flag.
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
      recommended = Inference.recommended(catalog).to_set

      catalog.to_h do |facts|
        by_person = facts.recommended_by_person
        [facts.id, Values.new(
          display_name: @names.fetch(facts.id), script_family: facts.script_family, rendering: facts.rendering,
          status: facts.status, superseded_by: replacements[facts.id],
          recommended: by_person.nil? ? recommended.include?(facts.id) : by_person,
        ).freeze,]
      end
    end

    # Sets the status on the facts and returns the replacement (a resource) or nil. A status
    # override wins; a replacement override alone makes the resource superseded.
    def lifecycle(facts, catalog)
      override = @overrides[facts.id]
      inferred, inferred_by = Inference.status(facts, catalog)
      facts.status = override[:status] || ('superseded' if override[:superseded_by]) || inferred || 'stable'

      override[:superseded_by] || (@by_id[inferred_by] if facts.status == 'superseded')
    end

    def links
      @links ||= begin
        requires = @facts.transform_values { |facts| facts.requires.first }.compact
        stored = @rows.map do |source, target, id|
          link(id, source, target, requires[source] == target ? 'requires' : 'pairs_with')
        end
        implied = requires.to_a - @rows.map { |row| row.first(2) }
        stored + implied.map { |source, target| link(nil, source, target) }
      end
    end

    def link(id, source, target, relation_type = 'requires')
      Link.new(id: id, source: @by_id.fetch(source), target: @by_id.fetch(target), relation_type: relation_type)
    end

    # The valid overrides of a resource: field => value.
    def overrides(resource)
      return {} if resource.meta_data.blank?

      OVERRIDES.to_h { |field, key| [field, override(field, resource.meta_value(key), resource)] }.compact
    end

    def override(field, value, resource)
      case field
      when :display_name then value.squish.presence if value.is_a?(String)
      when :script_family then choice(value, SCRIPT_FAMILIES)
      when :rendering then choice(value, RENDERINGS)
      when :status then choice(value, STATUSES)
      when :recommended then { 'true' => true, 'false' => false }[value.to_s.strip.downcase]
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

      @by_slug ||= @resources.select { |other| other.slug.present? }.index_by(&:slug)
      found = @by_slug[name] || (@by_id[name.to_i] if name.match?(/\A\d+\z/))
      found unless found&.id == resource.id
    end
  end
end
