# frozen_string_literal: true

# A table whose rows may be overridden per riwayah (P6.1/P6.2): translations,
# tafsirs and word_translations carry a nullable riwayah_id. A row with
# riwayah_id NULL is the shared text every riwayah reads; a row with a
# riwayah_id replaces the shared row of the same key for that riwayah only.
#
#   Translation.for_riwayah(warsh).where(resource_content_id: 131, verse_id: v.id)
#
# for_riwayah collapses to one row per key (DISTINCT ON the key columns,
# the override first) and is a relation, so the usual conditions chain on
# it; Postgres pushes conditions on the key columns into the subquery, so
# the existing indexes keep serving. Callers that pass no riwayah keep the
# old scopes and see every row, as before.
module RiwayahOverride
  extend ActiveSupport::Concern

  included do
    belongs_to :riwayah, optional: true

    scope :shared, -> { where(riwayah_id: nil) }
    scope :overrides, -> { where.not(riwayah_id: nil) }
    scope :overrides_for, ->(riwayah) { where(riwayah_id: riwayah) }
  end

  class_methods do
    # The columns that identify one piece of content (set per model).
    def override_key(*columns)
      @override_key_columns = columns.map(&:to_s) if columns.any?
      @override_key_columns or raise "#{name} declares no override_key"
    end

    # What `riwayah` reads: its override rows, and the shared rows of every
    # key it has no override for. nil reads the shared rows only.
    def for_riwayah(riwayah)
      riwayah_id = riwayah.is_a?(Riwayah) ? riwayah.id : riwayah
      return shared if riwayah_id.nil?

      keys = override_key.map { |c| "#{quoted_table_name}.#{connection.quote_column_name(c)}" }.join(', ')
      inner = unscoped.select(Arel.sql("DISTINCT ON (#{keys}) #{quoted_table_name}.*"))
                      .where(riwayah_id: [riwayah_id, nil])
                      .order(Arel.sql("#{keys}, #{quoted_table_name}.riwayah_id NULLS LAST"))
      from(inner, table_name)
    end
  end

  def override?
    riwayah_id.present?
  end
end
