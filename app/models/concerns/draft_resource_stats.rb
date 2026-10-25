# Per resource draft counts, used by the CMS draft sidebars. Call it on a scope to narrow it down.
module DraftResourceStats
  extend ActiveSupport::Concern

  class_methods do
    def resource_stats
      counts = all
                 .group(:resource_content_id)
                 .select("resource_content_id,
                   COUNT(*) AS total_count,
                   COUNT(CASE WHEN text_matched = true THEN 1 END) AS matched_count,
                   COUNT(CASE WHEN text_matched = false THEN 1 END) AS not_matched_count,
                   COUNT(CASE WHEN imported = true THEN 1 END) AS imported_count,
                   COUNT(CASE WHEN imported = false THEN 1 END) AS not_imported_count,
                   COUNT(CASE WHEN need_review = true THEN 1 END) AS need_review_count")

      resources = ResourceContent.where(id: counts.map(&:resource_content_id)).index_by(&:id)

      counts.map do |record|
        {
          resource: resources[record.resource_content_id],
          total_count: record.total_count.to_i,
          matched_count: record.matched_count.to_i,
          not_matched_count: record.not_matched_count.to_i,
          imported_count: record.imported_count.to_i,
          not_imported_count: record.not_imported_count.to_i,
          need_review_count: record.need_review_count.to_i
        }
      end
    end
  end
end
