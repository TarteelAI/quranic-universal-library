# frozen_string_literal: true

module Catalog
  # The name each resource is shown under. A resource whose name is unique inside its type keeps
  # it. Names that repeat inside a type get the qualifiers that differ inside the group:
  # recitation style, language (translations, tafsirs and other per-language types) and
  # granularity. Members the data cannot tell apart get a counter, in id order. A name an editor
  # set (`preset`, resource id => name) is used as it is and is never given to another resource.
  module DisplayNames
    LANGUAGE_TYPES = ['translation', 'tafsir', 'transliteration', 'surah-info'].freeze

    # Resource id => display name. `resources` are in id order, with `language` and
    # `resource_content: :language` preloaded.
    def self.call(resources, preset = {})
      names = resources.to_h { |resource| [resource.id, preset[resource.id] || resource.name] }
      resources.group_by(&:resource_type).each_value { |group| name_type(group, preset, names) }
      names
    end

    def self.name_type(resources, preset, names) # rubocop:disable Metrics/AbcSize -- one pass over a type's groups
      groups = resources.group_by { |resource| key(names[resource.id]) }.values.select { |group| group.size > 1 }
      pending = groups.flatten.reject { |resource| preset.key?(resource.id) }
      return if pending.empty?

      taken = (resources - pending).to_set { |resource| key(names[resource.id]) }
      qualifiers = Qualifiers.new(groups.flatten)

      groups.each do |group|
        varying = qualifiers.varying(group)
        (group & pending).each do |resource|
          names[resource.id] = free_name(resource.name, varying.call(resource), taken)
          taken << key(names[resource.id])
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

    # Style, language and granularity of each resource. Recitations are in the content database,
    # so their styles are loaded in separate queries.
    class Qualifiers
      def initialize(resources)
        @styles = recitation_styles(resources.select { |resource| resource.resource_type == 'recitation' })
      end

      # A function from a resource to the qualifiers whose values differ inside the group.
      def varying(group)
        values = group.index_with { |resource| of(resource) }
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

      # Some language names list variants ("Sinhala, Sinhalese"); the first one is enough.
      def language(resource)
        (resource.language || resource.resource_content&.language)&.name&.split(',')&.first
      end

      def recitation_styles(resources)
        content_ids = resources.filter_map(&:resource_content_id)
        return {} if content_ids.empty?

        [Recitation, Audio::Recitation].each_with_object({}) do |model, styles|
          model.where(resource_content_id: content_ids).preload(:recitation_style).each do |recitation|
            styles[recitation.resource_content_id] ||= recitation.recitation_style&.name
          end
        end
      end
    end
  end
end
