# frozen_string_literal: true

module Exporter
  # The text of a row-backed script (a riwayah's quran-text edition) as
  # downloads (P7.4): ayah by ayah in the riwayah's own numbering, and word
  # by word by shared number, each as JSON and SQLite, every archive with a
  # README carrying the licence of the script row and the attributions.
  #
  #   e = Exporter::ExportRiwayahText.new(script: Script.find_by!(slug: 'qpc-warsh'), base_path: 'tmp/export/riwayah_text')
  #   e.export('ayah', 'json') # => directory with ayah.json + README.md, ready to zip
  class ExportRiwayahText
    FORMATS = %w[json sqlite].freeze
    LEVELS = %w[ayah word].freeze

    attr_reader :script, :base_path

    def initialize(script:, base_path:)
      @script = script
      @base_path = base_path
      FileUtils.mkdir_p(base_path)
    end

    def numbering
      @numbering ||= script.riwayah&.default_numbering || AyahNumbering.kufi
    end

    # directory "<slug>-<level>-<format>" holding the data file and README.md
    def export(level, format)
      raise ArgumentError, "level #{level}" unless LEVELS.include?(level)
      raise ArgumentError, "format #{format}" unless FORMATS.include?(format)

      dir = File.join(base_path, "#{script.slug}-#{level}-#{format}")
      FileUtils.rm_rf(dir)
      FileUtils.mkdir_p(dir)
      rows = level == 'ayah' ? ayah_rows : word_rows
      if format == 'json'
        id = level == 'ayah' ? :key : :number # ayahs by their key, words by shared number
        File.write(File.join(dir, "#{level}.json"), JSON.generate(rows.to_h { |r| [r[id], r] }, { state: JsonNoEscapeHtmlState.new }))
      else
        write_sqlite(File.join(dir, "#{level}.sqlite"), level == 'ayah' ? 'ayahs' : 'words', rows)
      end
      File.write(File.join(dir, 'README.md'), readme(level))
      dir
    end

    # one row per ayah of the numbering (the uncounted basmalah of al-Fatihah included, counted: false)
    def ayah_rows
      @ayah_rows ||= numbering.numbered_ayahs.in_order.includes(:kufi_first_verse, :kufi_last_verse).map do |a|
        {
          key: a.ayah_key, surah: a.chapter_id, ayah: a.ayah_number, counted: a.counted,
          kufi_from: a.kufi_first_verse&.verse_key, kufi_to: a.kufi_last_verse&.verse_key, relation: a.relation,
          first_number: a.first_number, last_number: a.last_number, words_count: a.words_count,
          text: a.text_for(script)
        }
      end
    end

    # one row per word the script reads, by shared number, with its ayah in the riwayah's numbering
    def word_rows
      @word_rows ||= begin
        ayah_of = {}
        numbering.numbered_ayahs.in_order.each do |a|
          next unless a.first_number && a.last_number

          (a.first_number..a.last_number).each_with_index { |n, i| ayah_of[n] = [a.ayah_key, i + 1] }
        end
        WordText.where(script_id: script.id).joins(:word).includes(:word).merge(Word.unscoped.order(:number)).filter_map do |t|
          w = t.word
          next unless w.number

          key, position = ayah_of[w.number] || [nil, nil]
          { number: w.number, number_last: w.number_last, key: key, word: position, kufi_location: w.location, text: t.text }
        end
      end
    end

    def readme(level)
      lines = []
      lines << "# #{script.name} — #{level == 'ayah' ? 'ayah by ayah' : 'word by word'}"
      lines << ''
      lines << "Riwayah: #{script.riwayah&.name} (#{script.riwayah&.slug}). Ayah numbering: #{numbering.slug} (#{numbering.name_en}, #{numbering.total_ayahs} ayahs)."
      lines << "Source package: #{script.source_package}#{script.release_year ? " (#{script.release_year})" : ''}#{script.source_sha256 ? ", sha256 #{script.source_sha256}" : ''}."
      lines << ''
      lines << '## Columns'
      if level == 'ayah'
        lines << 'key, surah, ayah: the ayah in the riwayah\'s own numbering (ayah 0 = the uncounted basmalah of al-Fatihah).'
        lines << 'kufi_from, kufi_to, relation: the Kufi (Hafs) verses the ayah covers and how it relates to them (same, shifted, merged, split, unnumbered).'
        lines << 'first_number, last_number: the quran-text shared word numbers of its first and last word; words_count; text: the ayah text in this script.'
      else
        lines << 'number: the quran-text shared word number (the same word in every riwayah); number_last when one written word covers two numbers.'
        lines << 'key, word: the ayah in the riwayah\'s numbering and the word\'s position in it; kufi_location: the Hafs word location (surah:ayah:word); text: the word in this script.'
      end
      lines << ''
      lines << '## Licence and attribution'
      lines << (script.licence.presence || 'Text under the terms of the King Fahd Glorious Qur\'an Printing Complex (KFGQPC); derived work under CC BY 4.0.')
      lines << 'Shared word numbers, ayah numbering and ayah maps derive from quran-text and qiraat-ayah-map (CC BY 4.0, https://quran.ws). The text itself remains under KFGQPC terms.'
      lines << "Exported from the Quranic Universal Library on #{Date.today}."
      lines.join("\n") + "\n"
    end

    private

    def write_sqlite(path, table, rows)
      require 'sqlite3'
      File.delete(path) if File.exist?(path)
      db = SQLite3::Database.new(path)
      cols = rows.first&.keys || (table == 'ayahs' ? %i[key] : %i[number])
      types = cols.map { |c| %i[surah ayah first_number last_number words_count number number_last word].include?(c) ? 'INTEGER' : (c == :counted ? 'INTEGER' : 'TEXT') }
      db.execute("CREATE TABLE #{table} (#{cols.each_with_index.map { |c, i| "#{c} #{types[i]}" }.join(', ')})")
      stmt = db.prepare("INSERT INTO #{table} (#{cols.join(', ')}) VALUES (#{cols.map { '?' }.join(', ')})")
      db.transaction do
        rows.each { |r| stmt.execute(cols.map { |c| v = r[c]; v == true ? 1 : (v == false ? 0 : v) }) }
      end
      stmt.close
      db.close
    end
  end
end
