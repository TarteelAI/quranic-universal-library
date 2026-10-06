# frozen_string_literal: true

require 'json'

module Qiraat
  module Import
    # Printed numberings and default numberings per riwayah (P4.3).
    #
    # For each quran-text edition file, the printed ayah ends are read from
    # ayah_starts (positions -> shared numbers through the numbering block)
    # and compared with the madhhab the edition measures onto. When they are
    # identical the riwayah's default numbering is that madhhab; when they
    # differ (Susi: 6,218 against First Madinan 6,217; Bazzi: 6,220 against
    # Makki 6,219) a numbering of kind "printed" is built from the edition's
    # own ends and becomes the default. Riwayat without an edition default
    # to the madhhab attributed to their qari.
    class PrintedNumberings
      attr_reader :report

      def initialize(mushaf_dir:, counting_path:, catalog_path:, editions: nil, dry_run: false)
        @mushaf_dir = Pathname(mushaf_dir)
        @counting_path = counting_path
        @catalog_path = catalog_path
        @counting = JSON.parse(Pathname(counting_path).read)
        @editions = editions
        @dry_run = dry_run
        @report = { editions: {}, defaults: {} }
      end

      def call
        Qiraat::Import::ScriptText::EDITIONS.each do |key, (_slug, riwayah_slug, _css)|
          next if @editions && !@editions.include?(key)

          path = @mushaf_dir.join("#{key}.json")
          next unless path.exist?

          data = JSON.parse(path.read)
          system = data['counting']['system_printed'] || data['counting']['system']
          ends = printed_ends(data)
          madhhab_ends = @counting['systems'].fetch(system)['ayah_ends'].select { |n| n <= ends.max } # a partial file compares its own range
          riwayah = Riwayah.find_by!(slug: riwayah_slug)
          if ends == madhhab_ends
            numbering = AyahNumbering.find_by(slug: system)
            report[:editions][key] = { system: system, printed: ends.size, deviates: false, numbering: system }
          else
            slug = "kfgqpc-#{key}-#{(data['provenance']['text']['package'].to_s[/v-?\d+(\.\d+)?/i] || "v#{data['provenance']['text']['release_year']}").downcase.delete('-')}"
            diff = (ends - madhhab_ends).size + (madhhab_ends - ends).size
            report[:editions][key] = { system: system, printed: ends.size, deviates: true, numbering: slug, distance: diff }
            unless @dry_run
              builder = Qiraat::Import::Numberings.new(counting_path: @counting_path, catalog_path: @catalog_path, dry_run: false)
              builder.build_custom(
                slug: slug, ends: ends, kind: 'printed', counting_system_slug: system,
                name_en: "#{data['mushaf']['name_en']} (KFGQPC #{data['provenance']['text']['package']})",
                name_ar: data['mushaf']['name_ar'],
                source: "quran-text mushaf/#{key}.json ayah_starts, package #{data['provenance']['text']['package']}",
                meta: { 'edition' => key, 'madhhab' => system, 'distance_to_madhhab' => diff, 'khilaf' => data['counting']['khilaf'] },
                missing: data['numbering']['missing']
              )
              numbering = AyahNumbering.find_by!(slug: slug)
            end
          end
          next if @dry_run

          riwayah.update!(default_numbering_id: numbering.id)
          report[:defaults][riwayah_slug] = numbering.slug
        end
        attribute_defaults unless @dry_run
        report
      end

      private

      # Riwayat with no edition: the madhhab attributed to the qari.
      def attribute_defaults
        Riwayah.where(default_numbering_id: nil).includes(qiraah: :counting_system).find_each do |r|
          slug = r.qiraah&.counting_system&.slug
          numbering = slug && AyahNumbering.find_by(slug: slug)
          next unless numbering

          r.update!(default_numbering_id: numbering.id, meta_data: r.meta_data.merge('default_numbering_attributed' => true))
          report[:defaults][r.slug] = "#{numbering.slug} (attributed)"
        end
      end

      # Shared number of the last word of every ayah in the edition.
      def printed_ends(data)
        numbers = positions_to_numbers(data)
        starts = data['ayah_starts']
        starts.each_with_index.map do |s, i|
          last_pos = (starts[i + 1] || data['words'].size) - 1
          numbers[last_pos].max
        end
      end

      def positions_to_numbers(data)
        missing = data['numbering']['missing'].to_set
        joined = data['numbering']['written_joined'].to_h { |j| [j['position'], j['numbers']] }
        counter = 1
        data['words'].each_index.map do |pos|
          counter += 1 while missing.include?(counter)
          if (run = joined[pos])
            counter = run.max + 1
            run
          else
            n = counter
            counter += 1
            [n]
          end
        end
      end
    end
  end
end
