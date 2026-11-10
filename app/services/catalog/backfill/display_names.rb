# frozen_string_literal: true

module Catalog
  module Backfill
    # Gives a display name to resources whose name repeats inside their type, so every resource
    # is told apart within its type. The name gets the qualifiers that differ inside the group:
    # recitation style, language (translations, tafsirs and other per-language types) and
    # granularity, which are read from the content database. Members the data cannot tell
    # apart get a counter, in id order. Display names already set are never changed, and a
    # resource whose name is already unique keeps no display name of its own.
    module DisplayNames
      LANGUAGE_TYPES = %w[translation tafsir transliteration surah-info].freeze

      def self.call
        DownloadableResource.order(:id).group_by(&:resource_type).sum do |_type, resources|
          name_type(resources)
        end
      end

      def self.name_type(resources)
        groups = resources.group_by { |resource| key(resource.display_name) }.values.select { |group| group.size > 1 }
        pending = groups.flat_map { |group| group.select { |resource| resource[:display_name].blank? } }
        return 0 if pending.empty?

        taken = (resources - pending).to_set { |resource| key(resource.display_name) }
        qualifiers = Qualifiers.new(groups.flatten)

        groups.sum do |group|
          varying = qualifiers.varying(group)
          group.select { |resource| pending.include?(resource) }.sort_by(&:id).count do |resource|
            display_name = free_name(resource.name, varying.call(resource), taken)
            taken << key(display_name)
            next false if display_name == resource.name

            resource.update_columns(display_name: display_name)
          end
        end
      end

      def self.free_name(name, parts, taken)
        candidate = compose(name, parts)
        (2..).each do |n|
          return candidate unless taken.include?(key(candidate))

          candidate = compose(name, parts + [n.to_s])
        end
      end

      def self.compose(name, parts)
        parts.empty? ? name : "#{name} (#{parts.join(', ')})"
      end

      def self.key(name)
        name.to_s.squish.downcase
      end

      private_class_method :name_type, :free_name, :compose, :key

      # Style, language and granularity of each resource. Resource contents, recitations and
      # languages are in the content database, so they are loaded in separate queries.
      class Qualifiers
        def initialize(resources)
          content_ids = resources.map(&:resource_content_id)
          @contents = ResourceContent.where(id: content_ids).index_by(&:id)
          @styles = recitation_styles(content_ids)
          @languages = Language.where(id: resources.map(&:language_id) + @contents.values.map(&:language_id))
                               .index_by(&:id)
        end

        # A function from a resource to the qualifiers whose values differ inside the group.
        def varying(group)
          values = group.to_h { |resource| [resource, of(resource)] }
          columns = values.values.transpose
          dimensions = columns.each_index.select { |i| columns[i].uniq.size > 1 }

          ->(resource) { values[resource].values_at(*dimensions).compact_blank }
        end

        private

        def of(resource)
          case resource.resource_type
          when 'recitation' then [@styles[resource.resource_content_id], resource.humanize_cardinality_type]
          when *LANGUAGE_TYPES then [language(resource), resource.humanize_cardinality_type]
          else [resource.humanize_cardinality_type]
          end
        end

        def language(resource)
          language_id = resource.language_id || @contents[resource.resource_content_id]&.language_id
          # Some language names list variants ("Sinhala, Sinhalese"); the first one is enough.
          @languages[language_id]&.name&.split(',')&.first
        end

        def recitation_styles(content_ids)
          [Recitation, Audio::Recitation].each_with_object({}) do |model, styles|
            model.where(resource_content_id: content_ids).preload(:recitation_style).each do |recitation|
              styles[recitation.resource_content_id] ||= recitation.recitation_style&.name
            end
          end
        end
      end
    end
  end
end
