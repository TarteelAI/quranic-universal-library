# frozen_string_literal: true

module Qiraat
  module Seed
    # Registers the text already loaded in quran_script_by_verses and
    # quran_script_by_words as scripts rows with storage "legacy" (P3.7).
    #
    # Those tables hold raw ayah-level and word-level text keyed by the
    # riwayah's own numbering, published under existing resource_contents.
    # They stay: a riwayah may have several scripts (publishers, encodings),
    # and these are one of them. One scripts row is made per riwayah per
    # pair of (ayah resource, word resource); a resource with no partner
    # becomes a script on its own. Idempotent, matched by slug.
    class LegacyScripts
      attr_reader :report

      def initialize
        @report = { created: 0, updated: 0, scripts: [] }
      end

      def call
        ayah_by_riwayah = QuranScript::ByVerse.distinct.pluck(:qirat_id, :resource_content_id).group_by(&:first)
        word_by_riwayah = QuranScript::ByWord.distinct.pluck(:qirat_id, :resource_content_id).group_by(&:first)
        (ayah_by_riwayah.keys | word_by_riwayah.keys).compact.sort.each do |riwayah_id|
          riwayah = Riwayah.find(riwayah_id)
          ayah_rcs = (ayah_by_riwayah[riwayah_id] || []).map(&:last).sort
          word_rcs = (word_by_riwayah[riwayah_id] || []).map(&:last).sort
          pairs = pair(ayah_rcs, word_rcs)
          pairs.each { |ayah_rc, word_rc| upsert(riwayah, ayah_rc, word_rc, pairs.size) }
        end
        report
      end

      private

      # Zip ayah and word resources of a riwayah into scripts; leftovers stand alone.
      def pair(ayah_rcs, word_rcs)
        n = [ayah_rcs.size, word_rcs.size].max
        (0...n).map { |i| [ayah_rcs[i], word_rcs[i]] }
      end

      def upsert(riwayah, ayah_rc_id, word_rc_id, count)
        primary = ResourceContent.find_by(id: ayah_rc_id || word_rc_id)
        slug = count > 1 ? "legacy-#{riwayah.slug}-#{primary.name.parameterize}" : "legacy-#{riwayah.slug}"
        css = primary.meta_value('font-face').presence || riwayah_font(riwayah)
        row = Script.find_or_initialize_by(slug: slug)
        report[row.new_record? ? :created : :updated] += 1
        row.assign_attributes(
          name: "#{primary.name.strip} (legacy #{riwayah.name_en || riwayah.name})",
          riwayah: riwayah, kind: 'unicode', storage: 'legacy', column_name: nil,
          font_family: css, font_css_class: css,
          ayah_resource_content_id: ayah_rc_id, word_resource_content_id: word_rc_id,
          enabled: true, # already published downloads
          meta_data: row.meta_data.merge(
            'legacy' => true,
            'numbering' => "the riwayah's own ayah and word numbers (keys like 2:1, 2:1:3)",
            'ayah_rows' => ayah_rc_id ? QuranScript::ByVerse.where(resource_content_id: ayah_rc_id).count : 0,
            'word_rows' => word_rc_id ? QuranScript::ByWord.where(resource_content_id: word_rc_id).count : 0
          )
        )
        row.save!
        report[:scripts] << [row.slug, ayah_rc_id, word_rc_id]
      end

      def riwayah_font(riwayah)
        Script.row_backed.find_by(riwayah_id: riwayah.id)&.font_css_class || 'qpc-hafs'
      end
    end
  end
end
