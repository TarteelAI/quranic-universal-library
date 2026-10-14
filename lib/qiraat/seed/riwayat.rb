# frozen_string_literal: true

require 'json'

module Qiraat
  module Seed
    # Seeds the twenty rawis from the pinned qiraat-ayah-map qiraat.json into
    # riwayat, preserving the ids of the rows that existed as qirat_types.
    #
    # Existing rows are matched by their legacy `name` (LEGACY_NAMES); every
    # other rawi is inserted. Idempotent: rerunning updates in place.
    class Riwayat
      # Legacy qirat_types.name => upstream rawi slug.
      LEGACY_NAMES = {
        'Hafs' => 'hafs',
        'Warsh' => 'warsh',
        'Sousi' => 'susi',
        'Khalaf' => 'khalaf', # the rawi of Hamza; see UNVERIFIED
        'Qaloun' => 'qalun',
        'Douri' => 'duri',
        'Shuba' => 'shuba'
      }.freeze

      # Rows whose identity could not be confirmed from the data that
      # produced them. The existing "Khalaf" script resources (1655, 1656)
      # have no recorded source, so whether they are Khalaf 'an Hamza or
      # Khalaf al-Ashir is unknown; mapped to Hamza's rawi provisionally.
      UNVERIFIED = {
        'khalaf' => 'Mapped to Khalaf an Hamza provisionally: the original import did not record which Khalaf. Confirm before enabling.'
      }.freeze

      # Legacy rows that are not riwayat and have no references.
      LEGACY_DELETE = ['Test'].freeze

      attr_reader :dir, :report

      def initialize(dir:)
        @dir = Pathname(dir)
        @report = { matched: 0, created: 0, deleted: 0 }
      end

      def call
        qiraat = JSON.parse(dir.join('qiraat.json').read)
        qiraah_rows = Qiraah.all.index_by(&:slug)
        existing_by_name = Riwayah.where(slug: nil).index_by(&:name)

        qiraat.each do |qiraah_slug, q|
          qiraah = qiraah_rows.fetch(qiraah_slug) { raise "qiraah #{qiraah_slug} not seeded; run Qiraat::Seed::Reference first" }
          q['rawis'].each do |rawi_slug, r|
            row = Riwayah.find_by(slug: rawi_slug)
            if row.nil?
              legacy_name = LEGACY_NAMES.key(rawi_slug)
              row = legacy_name && existing_by_name[legacy_name]
              if row
                report[:matched] += 1
              else
                row = Riwayah.new(name: r['name_en'])
                report[:created] += 1
              end
            end
            row.assign_attributes(
              slug: rawi_slug,
              qiraah: qiraah,
              name_ar: r['name_ar'],
              name_en: r['name_en'],
              meta_data: row.meta_data.merge(unverified_meta(rawi_slug))
            )
            row.name ||= r['name_en']
            row.save!
          end
        end

        Riwayah.where(slug: nil, name: LEGACY_DELETE).find_each do |row|
          next if row.mushafs.exists? || row.verse_recitations.exists? || row.audio_recitations.exists?

          row.destroy!
          report[:deleted] += 1
        end

        report
      end

      private

      def unverified_meta(slug)
        return {} unless UNVERIFIED.key?(slug)

        { 'unverified' => true, 'unverified_note' => UNVERIFIED[slug] }
      end
    end
  end
end
