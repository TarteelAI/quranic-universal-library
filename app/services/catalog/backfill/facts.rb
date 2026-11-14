# frozen_string_literal: true

module Catalog
  module Backfill
    # The facts the inference rules read (Catalog::Inference::Facts), for every resource as it is
    # now: CMS rows with their tags, files and links, then content rows, languages and mushafs
    # from the content database in separate queries.
    module Facts
      module_function

      # Pairs of [resource, facts], in id order.
      def load
        resources = DownloadableResource.order(:id)
                                        .preload(:downloadable_resource_tags, :downloadable_files,
                                                 :downloadable_related_resources, :language,
                                                 resource_content: :language)
                                        .to_a
        types = resources.to_h { |resource| [resource.id, resource.resource_type] }
        resources.map { |resource| [resource, build(resource, types)] }
      end

      def build(resource, types)
        content = resource.resource_content
        drafted = Review.drafted(resource.review)
        links = resource.downloadable_related_resources

        Inference::Facts.new(
          id: resource.id, type: resource.resource_type, type_label: Taxonomy.type(resource.resource_type)&.label,
          name: resource.name, cardinality: resource.cardinality_type, published: resource.published,
          status: resource.status, script_family: resource.script_family, rendering: resource.rendering,
          recommended_by_person: recommended_by_person(resource, drafted),
          language: (resource.language || content&.language)&.name&.split(',')&.first,
          tags: resource.downloadable_resource_tags.map(&:name),
          formats: resource.downloadable_files.select(&:published).map(&:file_type),
          requires: links.select(&:requires?).map(&:related_resource_id),
          linked_fonts: links.map(&:related_resource_id).select { |id| types[id] == 'font' }
                             .reject { |id| drafted.key?("link:#{id}") },
          **script_facts(resource, content)
        )
      end

      # A person's decision on the recommended flag: the value when it is reviewed, or set and not
      # drafted; nil when nobody decided.
      def recommended_by_person(resource, drafted)
        decided = Review.reviewed(resource.review).key?('recommended') ||
                  (resource.recommended && !drafted.key?('recommended'))
        resource.recommended if decided
      end

      def script_facts(resource, content)
        meta = ->(key) { content&.meta_value(key).presence }

        case resource.resource_type
        when 'quran-script'
          { text_types: [meta['text-type']].compact, font_codes: [meta['font'], meta['font-face']].compact }
        when 'mushaf-layout'
          mushaf = MushafLayouts::Page.mushaf_for(resource) if content
          { text_types: [meta['text-type']].compact, font_codes: [mushaf&.default_font_name].compact,
            mushaf: mushaf && Inference::Mushaf.new(font: mushaf.default_font_name, default: mushaf.is_default,
                                                   pages: mushaf.pages_count, lines: mushaf.lines_per_page) }
        when 'font'
          { text_types: [resource.meta_value('script'), meta['script']].compact_blank,
            font_codes: [resource.meta_value('font-face'), meta['font-face'], meta['font-path']].compact_blank,
            per_page: Fonts::UrlResolver::FORMATS.keys.any? { |format| File.basename(meta[format].to_s) == format },
            svg: meta['svg-template'].present? }
        else
          { text_types: [], font_codes: [] }
        end
      end
    end
  end
end
