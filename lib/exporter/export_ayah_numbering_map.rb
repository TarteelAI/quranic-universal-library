# frozen_string_literal: true

require 'csv'

module Exporter
  # The ayah numbering map as downloads (P7.4): for every Kufi verse, the
  # ayah it falls in under each other numbering (madhhab and printed) and
  # the relation — the same shape as quran-text's ayah-map, built from
  # ayah_mappings. JSON and CSV, each in a directory with a README.
  class ExportAyahNumberingMap
    attr_reader :base_path

    def initialize(base_path:)
      @base_path = base_path
      FileUtils.mkdir_p(base_path)
    end

    def numberings
      @numberings ||= AyahNumbering.where.not(slug: 'kufi').order(:id).to_a
    end

    def export(format)
      dir = File.join(base_path, "ayah-numbering-map-#{format}")
      FileUtils.rm_rf(dir)
      FileUtils.mkdir_p(dir)
      case format
      when 'json' then File.write(File.join(dir, 'ayah-map.json'), JSON.generate(json_data))
      when 'csv' then write_csv(File.join(dir, 'ayah-map.csv'))
      else raise ArgumentError, "format #{format}"
      end
      File.write(File.join(dir, 'README.md'), readme)
      dir
    end

    def entries
      @entries ||= begin
        mappings = AyahMapping.where(numbering_id: numberings.map(&:id)).includes(:ayah, :ayah_last).group_by(&:verse_id)
        Verse.unscoped.order(:id).pluck(:id, :chapter_id, :verse_number, :verse_key).map do |id, surah, ayah, key|
          entry = { 'surah' => surah, 'ayah' => ayah, 'verse_id' => id, 'verse_key' => key }
          (mappings[id] || []).each do |m|
            n = numberings.find { |x| x.id == m.numbering_id }
            next unless n

            e = { 'surah' => m.ayah.chapter_id, 'ayah' => m.ayah.ayah_number, 'relation' => m.relation }
            e['ayah_last'] = m.ayah_last.ayah_number if m.ayah_last_id
            entry[n.slug] = e
          end
          entry
        end
      end
    end

    def json_data
      {
        'format' => 'qul-ayah-map', 'format_version' => '1.0', 'generated' => Date.today.to_s, 'reference' => 'kufi',
        'numberings' => numberings.map { |n| { 'slug' => n.slug, 'kind' => n.kind, 'name' => n.name_en, 'counting_system' => n.counting_system&.slug, 'total_ayahs' => n.total_ayahs, 'basmalah_counted' => n.basmalah_counted } },
        'note' => 'One entry per Kufi (Hafs) verse. For each numbering: the ayah its words fall in (ayah_last when they span a split) and the relation — same, shifted, merged, split, or unnumbered for the basmalah of al-Fatihah.',
        'ayahs' => entries
      }
    end

    def write_csv(path)
      CSV.open(path, 'w') do |csv|
        csv << %w[surah ayah verse_id] + numberings.flat_map { |n| ["#{n.slug}_ayah", "#{n.slug}_relation"] }
        entries.each do |e|
          csv << [e['surah'], e['ayah'], e['verse_id']] + numberings.flat_map do |n|
            m = e[n.slug]
            m ? ["#{m['surah']}:#{m['ayah']}#{m['ayah_last'] ? "-#{m['ayah_last']}" : ''}", m['relation']] : [nil, nil]
          end
        end
      end
    end

    def readme
      <<~MD
        # Ayah numbering map

        One row per Kufi (Hafs) verse — the numbering QUL keys everything by — with the ayah it falls in under every other numbering QUL holds and the relation between them: same, shifted (same ayah, other number), merged (the Kufi verse is part of a longer ayah), split (the Kufi verse spans two ayahs: ayah_last gives the second), unnumbered (the basmalah of al-Fatihah where it is not counted).

        Numberings: #{numberings.map { |n| "#{n.slug} (#{n.kind}, #{n.total_ayahs} ayahs)" }.join('; ')}.

        ## Licence and attribution
        Derived from quran-text and qiraat-ayah-map (https://quran.ws), CC BY 4.0; the counting data follows the printed KFGQPC editions. Exported from the Quranic Universal Library on #{Date.today}.
      MD
    end
  end
end
