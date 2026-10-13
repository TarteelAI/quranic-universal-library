# frozen_string_literal: true

require 'json'
require 'fileutils'

module Qiraat
  # Digests of the Hafs data the riwayah work must not change.
  #
  # Each entry is a row count plus a SHA-256 over the rows in primary-key
  # order, computed inside Postgres so the 2.18M-row mushaf_words table is
  # digested in seconds. The snapshot is written once to tmp/qiraat/baseline.json
  # and every later run compares against it; see rake qiraat:verify:baseline.
  class Baseline
    DEFAULT_PATH = Rails.root.join('tmp', 'qiraat', 'baseline.json')

    WORD_TEXT_COLUMNS = %w[
      text_uthmani text_uthmani_simple text_uthmani_tajweed text_imlaei text_imlaei_simple
      text_indopak text_indopak_nastaleeq text_indopak_misbah text_qpc_hafs text_qpc_hafs_tajweed
      text_qpc_nastaleeq text_qpc_nastaleeq_hafs text_digital_khatt text_digital_khatt_v1
      text_digital_khatt_indopak text_indonesian_sign_language code_v1 code_v2
    ].freeze

    VERSE_TEXT_COLUMNS = (WORD_TEXT_COLUMNS - %w[code_v1 code_v2]).freeze

    attr_reader :path

    def initialize(path: DEFAULT_PATH)
      @path = Pathname(path)
    end

    def exists?
      path.exist?
    end

    # @return [Hash] section => { key => { 'count' => n, 'sha256' => hex } }
    def compute
      {
        'generated_at' => Time.now.utc.iso8601,
        'database' => quran.current_database,
        'verses' => digest_columns('verses', 'id', VERSE_TEXT_COLUMNS),
        # Hafs rows only: the shared-word skeleton also holds words other riwayat
        # read (hafs_reads = false, no Hafs text); they are not Hafs data.
        'words' => digest_columns('words', 'id', WORD_TEXT_COLUMNS, extra_where: (quran.column_exists?('words', 'hafs_reads') ? 'hafs_reads = TRUE' : nil)),
        'mushaf_words' => digest_grouped('mushaf_words', 'mushaf_id',
                                         %w[word_id verse_id page_number line_number position_in_page position_in_line position_in_verse char_type_name text]),
        'mushaf_pages' => digest_grouped('mushaf_pages', 'mushaf_id',
                                         %w[page_number first_verse_id last_verse_id first_word_id last_word_id verses_count lines_count]),
        'translations' => digest_grouped('translations', 'resource_content_id', %w[verse_id text]),
        'tafsirs' => digest_grouped('tafsirs', 'resource_content_id', %w[verse_id start_verse_id end_verse_id group_verse_key_from group_verse_key_to text]),
        'word_translations' => digest_grouped('word_translations', 'resource_content_id', %w[word_id language_id text group_word_id group_text]),
        'chapters' => digest_columns('chapters', 'id', %w[verses_count bismillah_pre name_simple]),
        # audio (P7.3): the Kufi keys and timings; ayah_id / number_segments are the new columns and stay out
        'audio_files' => digest_grouped('audio_files', 'recitation_id', %w[verse_id verse_key verse_number segments segments_count]),
        'audio_segments' => digest_grouped('audio_segments', 'audio_recitation_id', %w[verse_id verse_key verse_number timestamp_from timestamp_to segments segments_count])
      }
    end

    def write!(data = compute)
      FileUtils.mkdir_p(path.dirname)
      path.write(JSON.pretty_generate(data))
      data
    end

    def read
      JSON.parse(path.read)
    end

    # @return [Array<String>] human-readable differences; empty when identical
    def compare(current = compute, stored = read)
      diffs = []
      (stored.keys - %w[generated_at database]).each do |section|
        before = stored[section]
        after = current[section] || {}
        (before.keys | after.keys).sort.each do |key|
          b = before[key]
          a = after[key]
          if b.nil?
            diffs << "#{section}[#{key}]: new (count #{a['count']})"
          elsif a.nil?
            diffs << "#{section}[#{key}]: missing (was count #{b['count']})"
          elsif a['count'] != b['count']
            diffs << "#{section}[#{key}]: count #{b['count']} -> #{a['count']}"
          elsif a['sha256'] != b['sha256']
            diffs << "#{section}[#{key}]: content changed (count #{a['count']} unchanged)"
          end
        end
      end
      diffs
    end

    private

    def quran
      Verse.connection
    end

    def q(ident)
      quran.quote_column_name(ident)
    end

    # One digest per column over the whole table, keyed "<column>".
    def digest_columns(table, order, columns, extra_where: nil)
      cols = columns.select { |c| quran.column_exists?(table, c) }
      selects = cols.map do |c|
        "encode(sha256(convert_to(coalesce(string_agg(#{q(order)}::text || '|' || coalesce(#{q(c)}::text, ''), E'\\n' ORDER BY #{q(order)}), ''), 'UTF8')), 'hex') AS #{q(c)}"
      end
      where = extra_where ? "WHERE #{extra_where}" : ''
      row = quran.select_one("SELECT count(*) AS n, #{selects.join(', ')} FROM #{q(table)} #{where}")
      out = { '_rows' => { 'count' => row['n'].to_i, 'sha256' => nil } }
      cols.each { |c| out[c] = { 'count' => row['n'].to_i, 'sha256' => row[c] } }
      out
    end

    # One digest per group value (e.g. per mushaf_id), over the listed columns.
    def digest_grouped(table, group, columns)
      cols = columns.select { |c| quran.column_exists?(table, c) }
      expr = cols.map { |c| "coalesce(#{q(c)}::text, '')" }.join(" || '|' || ")
      sql = <<~SQL
        SELECT #{q(group)} AS g, count(*) AS n,
               encode(sha256(convert_to(string_agg(#{expr}, E'\\n' ORDER BY id), 'UTF8')), 'hex') AS h
        FROM #{q(table)}
        GROUP BY #{q(group)}
        ORDER BY #{q(group)}
      SQL
      quran.select_all(sql).each_with_object({}) do |r, h|
        h[r['g'].to_s] = { 'count' => r['n'].to_i, 'sha256' => r['h'] }
      end
    end
  end
end
