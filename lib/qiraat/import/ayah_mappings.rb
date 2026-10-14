# frozen_string_literal: true

module Qiraat
  module Import
    # Precomputes ayah_mappings: Kufi verse -> ayah (or ayah range) in each
    # numbering (P4.3). Derived from the anchors on numbered_ayahs:
    #
    #   one ayah covers the verse            -> that ayah, its relation
    #   several ayahs share the verse        -> first..last, relation split
    #   the ayah also covers the next verse  -> merges_with_next
    #   the verse is an unnumbered basmalah  -> ayah 0, relation unnumbered
    #
    # Idempotent: each numbering's mappings are rebuilt on every run.
    class AyahMappings
      attr_reader :report

      def initialize(numberings: nil, dry_run: false)
        @numberings = numberings
        @dry_run = dry_run
        @report = {}
      end

      def call
        scope = AyahNumbering.order(:id)
        scope = scope.where(slug: @numberings) if @numberings
        scope.each do |numbering|
          rows = rows_for(numbering)
          report[numbering.slug] = { rows: rows.size, relations: rows.group_by { |r| r[:relation] }.transform_values(&:size),
                                     splits: rows.count { |r| r[:ayah_last_id] }, merges_with_next: rows.count { |r| r[:merges_with_next] } }
          next if @dry_run

          AyahMapping.where(numbering_id: numbering.id).delete_all
          rows.each_slice(2000) { |slice| AyahMapping.insert_all!(slice) }
        end
        report
      end

      private

      def rows_for(numbering)
        ayahs = numbering.numbered_ayahs.where.not(kufi_first_verse_id: nil).in_order.pluck(:id, :chapter_id, :ayah_number, :kufi_first_verse_id, :kufi_last_verse_id, :relation)
        by_verse = Hash.new { |h, k| h[k] = [] }
        ayahs.each do |id, chapter_id, number, first, last, relation|
          (first..last).each { |vid| by_verse[vid] << [id, chapter_id, number, first, last, relation] }
        end
        Verse.order(:id).pluck(:id).filter_map do |vid|
          covering = by_verse[vid]
          next if covering.empty?

          if covering.size == 1
            id, _c, _n, _first, last, relation = covering.first
            { numbering_id: numbering.id, verse_id: vid, ayah_id: id, ayah_last_id: nil, relation: relation, merges_with_next: last > vid }
          else
            { numbering_id: numbering.id, verse_id: vid, ayah_id: covering.first[0], ayah_last_id: covering.last[0], relation: 'split',
              merges_with_next: covering.last[4] > vid }
          end
        end
      end
    end
  end
end
