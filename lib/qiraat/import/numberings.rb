# frozen_string_literal: true

require 'json'

module Qiraat
  module Import
    # Builds the six madhhab numberings from quran-text counting.json (P4.2).
    #
    # counting.json lists, per system, the shared number after which every
    # one of its ayahs ends. Surah boundaries come from catalog.json
    # (first_number / last_number per surah). Walking the ends inside each
    # surah yields the ayahs as shared-number ranges; each range is anchored
    # to the Kufi verses of its first and last word (QUL words.number) and
    # given a relation to the Kufi count:
    #
    #   same        the range is exactly one Kufi verse (its number may differ)
    #   shifted     exactly one Kufi verse, but the editions of this numbering
    #               do not read every shared number inside it (40:26 lacks أَوۡ
    #               outside Hafs, Shubah), so the printed word set differs
    #   merged      the range spans two or more Kufi verses
    #   split       the range is part of one Kufi verse
    #   unnumbered  the Fatihah basmalah printed without a number (ayah 0)
    #
    # These are the relations quran-text ayah-map.json uses, so the verify
    # task can compare counts one to one.
    #
    # The Kufi numbering is built the same way and its rows take the ids of
    # the Kufi verses, so numbered_ayahs.id == verses.id for Kufi; every
    # other numbering continues the sequence above 6236.
    #
    # Idempotent: each numbering's rows are rebuilt on every run.
    class Numberings
      attr_reader :report

      # @param counting_path  quran-text data/counting.json
      # @param catalog_path   quran-text data/catalog.json (surah ranges)
      # @param systems        slugs to build (default: all in the file)
      # @param surahs         restrict to these surah numbers (fixtures)
      # @param missing   { system slug => Set of shared numbers its editions do not read }
      def initialize(counting_path:, catalog_path:, systems: nil, surahs: nil, dry_run: false, source: nil, missing: {})
        @counting = JSON.parse(Pathname(counting_path).read)
        @catalog = JSON.parse(Pathname(catalog_path).read)
        @systems = systems
        @surahs = surahs
        @dry_run = dry_run
        @missing = missing
        @source = source || "quran-text counting.json (#{@counting['generated']})"
        @report = {}
      end

      def call
        word_ids = words_by_number
        verse_by_word = verse_by_word_id
        kufi_ranges = kufi_ranges_by_verse
        chapter_ids = Chapter.pluck(:chapter_number, :id).to_h

        # Kufi first: its rows take the verse ids (1..6236); every other
        # numbering is inserted above that range.
        systems = @counting['systems'].sort_by { |slug, _| slug == 'kufi' ? 0 : 1 }
        reserve_kufi_ids unless @dry_run
        systems.each do |slug, system|
          next if @systems && !@systems.include?(slug)

          rows = build_rows(slug, system, word_ids, verse_by_word, kufi_ranges, chapter_ids)
          report[slug] = summarize(rows)
          next if @dry_run

          write(slug, system, rows)
        end
        report
      end

      # Build one numbering from an explicit list of ayah ends (shared numbers),
      # used for printed numberings that deviate from their madhhab (P4.3).
      def build_custom(slug:, ends:, kind:, counting_system_slug:, name_en:, name_ar: nil, source: nil, meta: {}, missing: [])
        @missing[slug] = missing.to_set
        word_ids = words_by_number
        rows = build_rows(slug, { 'ayah_ends' => ends }, word_ids, verse_by_word_id, kufi_ranges_by_verse, Chapter.pluck(:chapter_number, :id).to_h)
        report[slug] = summarize(rows)
        return report[slug] if @dry_run

        reserve_kufi_ids
        numbering = AyahNumbering.find_or_initialize_by(slug: slug)
        numbering.assign_attributes(kind: kind, counting_system: CountingSystem.find_by(slug: counting_system_slug), name_en: name_en, name_ar: name_ar,
                                    total_ayahs: rows.count { |r| r[:counted] }, source: source || @source,
                                    basmalah_counted: rows.none? { |r| r[:ayah_number].zero? }, meta_data: numbering.meta_data.merge(meta))
        numbering.save!
        insert_rows(numbering, slug, rows)
        report[slug]
      end

      private

      def surah_ranges
        @surah_ranges ||= @catalog['surahs'].select { |s| @surahs.nil? || @surahs.include?(s['number']) }
                                            .map { |s| [s['number'], s['first_number'], s['last_number']] }
      end

      def build_rows(slug, system, word_ids, verse_by_word, kufi_ranges, chapter_ids)
        ends = system['ayah_ends']
        rows = []
        index = 0
        surah_ranges.each do |surah, first_number, last_number|
          surah_ends = ends.select { |e| e.between?(first_number, last_number) }
          start = first_number
          # Fatihah basmalah printed unnumbered: words before the first end
          if surah == 1 && surah_ends.first && surah_ends.first > first_number + 3
            rows << row_for(slug, surah, 0, nil, first_number, first_number + 3, false, 'unnumbered', word_ids, verse_by_word, chapter_ids)
            start = first_number + 4
          end
          surah_ends.each_with_index do |e, i|
            index += 1
            rows << row_for(slug, surah, i + 1, index, start, e, true, nil, word_ids, verse_by_word, chapter_ids)
            start = e + 1
          end
        end
        # Only numbers Hafs reads count as missing: a word absent from Hafs too
        # (25685) does not change the Kufi verse's printed word set. A word
        # the editions read that Hafs does not (Bazzi's 25685 inside Kufi
        # 9:100) makes the ayah cover more than the verse: merged, as
        # ayah-map.json has it. Without edition files nothing is known about
        # extra words, so none are assumed.
        editions_known = @missing.key?(slug)
        missing = @missing.fetch(slug, Set.new) & hafs_numbers
        extra = editions_known ? all_numbers - hafs_numbers - @missing[slug].to_set : Set.new # read by the editions, not by Hafs
        rows.each { |r| r[:relation] ||= relation_for(r, kufi_ranges, missing, extra) }
        rows
      end

      def row_for(slug, surah, ayah_number, ayah_index, first_number, last_number, counted, relation, word_ids, verse_by_word, chapter_ids)
        first_word_id = word_ids[first_number]
        last_word_id = word_ids[last_number]
        {
          slug: slug, chapter_id: chapter_ids.fetch(surah), ayah_number: ayah_number, ayah_key: "#{surah}:#{ayah_number}",
          ayah_index: ayah_index, counted: counted,
          first_number: first_number, last_number: last_number,
          first_word_id: first_word_id, last_word_id: last_word_id,
          words_count: (first_number..last_number).count { |n| word_ids[n] },
          kufi_first_verse_id: first_word_id && verse_by_word[first_word_id],
          kufi_last_verse_id: last_word_id && verse_by_word[last_word_id],
          relation: relation
        }
      end

      def relation_for(row, kufi_ranges, missing, extra)
        return nil unless row[:kufi_first_verse_id] && row[:kufi_last_verse_id]
        return 'merged' if row[:kufi_first_verse_id] != row[:kufi_last_verse_id]

        kufi = kufi_ranges[row[:kufi_first_verse_id]]
        if kufi[:first] == row[:first_number] && kufi[:last] == row[:last_number]
          range = (row[:first_number]..row[:last_number])
          return 'merged' if range.any? { |n| extra.include?(n) }

          range.any? { |n| missing.include?(n) } ? 'shifted' : 'same'
        else
          'split'
        end
      end

      def summarize(rows)
        counted = rows.count { |r| r[:counted] }
        { ayahs: counted, rows: rows.size, relations: rows.group_by { |r| r[:relation] }.transform_values(&:size),
          unanchored: rows.count { |r| r[:counted] && r[:kufi_first_verse_id].nil? } }
      end

      # Rows of other numberings sitting in the verse-id range (from a run that
      # inserted them before Kufi) are removed so Kufi can take those ids; the
      # sequence is moved past the range so later inserts never land there.
      def reserve_kufi_ids
        max_verse = Verse.maximum(:id).to_i
        kufi = AyahNumbering.find_by(slug: 'kufi')
        stray = NumberedAyah.where('id <= ?', max_verse)
        stray = stray.where.not(numbering_id: kufi.id) if kufi
        if stray.exists?
          report[:rebuilt_after_stray_ids] = stray.distinct.pluck(:numbering_id)
          stray.delete_all
        end
        NumberedAyah.connection.execute("SELECT setval(pg_get_serial_sequence('numbered_ayahs', 'id'), GREATEST((SELECT MAX(id) FROM numbered_ayahs), #{max_verse}))")
      end

      def write(slug, system, rows)
        numbering = AyahNumbering.find_or_initialize_by(slug: slug)
        numbering.assign_attributes(
          kind: 'madhhab',
          counting_system: CountingSystem.find_by(slug: slug),
          name_en: system['name_en'], name_ar: system['name_ar'],
          total_ayahs: rows.count { |r| r[:counted] },
          source: @source,
          basmalah_counted: rows.none? { |r| r[:ayah_number].zero? },
          meta_data: numbering.meta_data.merge('reference_total' => system['reference_total'], 'editions' => system['editions'].map { |e| e['mushaf'] })
        )
        numbering.save!
        insert_rows(numbering, slug, rows)
      end

      def insert_rows(numbering, slug, rows)
        numbering.numbered_ayahs.delete_all
        attrs = rows.map do |r|
          base = r.except(:slug).merge(numbering_id: numbering.id)
          base[:id] = r[:kufi_first_verse_id] if slug == 'kufi' && r[:relation] == 'same' # Kufi rows take the verse ids
          base
        end
        attrs.each_slice(2000) { |slice| NumberedAyah.insert_all!(slice) }
        inserted = numbering.numbered_ayahs.count
        raise "#{slug}: inserted #{inserted} of #{attrs.size} rows" unless inserted == attrs.size

        NumberedAyah.connection.execute("SELECT setval(pg_get_serial_sequence('numbered_ayahs', 'id'), GREATEST((SELECT MAX(id) FROM numbered_ayahs), #{Verse.maximum(:id).to_i}))")
      end

      def all_numbers
        @all_numbers ||= Word.unscoped.where.not(number: nil).pluck(:number, :number_last).flat_map { |n, l| (n..(l || n)).to_a }.to_set
      end

      def hafs_numbers
        @hafs_numbers ||= Word.unscoped.hafs.where.not(number: nil).pluck(:number, :number_last).flat_map { |n, l| (n..(l || n)).to_a }.to_set
      end

      # shared number => words.id (number_last ranges included)
      def words_by_number
        map = {}
        Word.unscoped.where.not(number: nil).pluck(:id, :number, :number_last).each do |id, n, last|
          (n..(last || n)).each { |x| map[x] = id }
        end
        map
      end

      def verse_by_word_id
        Word.unscoped.where.not(number: nil).pluck(:id, :verse_id).to_h
      end

      # verse id => { first:, last: shared numbers of its Hafs words, ayah_number: }
      def kufi_ranges_by_verse
        rows = Word.unscoped.hafs.where.not(number: nil).group(:verse_id).pluck(:verse_id, Arel.sql('MIN(number)'), Arel.sql('MAX(COALESCE(number_last, number))'))
        numbers = Verse.pluck(:id, :verse_number).to_h
        rows.to_h { |vid, first, last| [vid, { first: first, last: last, ayah_number: numbers[vid] }] }
      end
    end
  end
end
