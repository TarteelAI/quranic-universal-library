# frozen_string_literal: true

module Catalog
  # Counts of the published catalog, for the home page: resources, the languages they are in,
  # recitations, and resources per category and type.
  #
  # A resource's language is the CMS row's, else its content row's (as in SearchQuery). Content
  # rows are in the Quran content database, so they are read in a second query.
  class Stats
    CategoryCount = Data.define(:key, :label, :hint, :count)
    Result = Data.define(:resources, :languages, :recitations, :per_type) do
      # Every category in taxonomy order, including those with no resources.
      def categories
        Taxonomy.types.group_by(&:category).map do |category, types|
          CategoryCount.new(key: category.key, label: category.label, hint: category.hint,
                            count: types.sum { |type| per_type.fetch(type.key, 0) },)
        end
      end
    end

    def call
      rows = DownloadableResource.published.pluck(:resource_type, :language_id, :resource_content_id)
      content_languages = ResourceContent.where(id: rows.map(&:third).compact).pluck(:id, :language_id).to_h
      language_ids = rows.filter_map { |_type, language_id, content_id| language_id || content_languages[content_id] }
      per_type = rows.map(&:first).tally

      Result.new(
        resources: rows.size,
        languages: Language.where(id: language_ids.uniq).count,
        recitations: per_type.fetch('recitation', 0),
        per_type: per_type
      )
    end
  end
end
