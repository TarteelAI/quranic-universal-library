class ExportedWord < ApplicationRecord
end

class ExportedLayout < ApplicationRecord
  self.inheritance_column = nil

  validates :page, presence: true, uniqueness: { scope: [:range_start, :line] }
end

class ExportMushafLayout
  MUSHAF_IDS = [
    2, # v1
    1, # v2
    5, # KFGQPC HAFS
    6, # Indopak 15 lines
    # 7, # Indopak 16 lines surah name and bismillah is one the same line for some pages
    # 8, # Indopak 14 lines Pak company has wrong line alignments data
    # 16, # QPC Hafs with tajweed
    17, # Indopak 13 lines
    20, # Digital Khatt v2
    22, # Digital Khatt v1
  ]
  attr_accessor :mushafs,
                :stats

  def initialize
    @mushafs = []
    @stats = {}
  end

  def export(ids = MUSHAF_IDS, db_name = "quran-data.sqlite")
    @mushafs = Mushaf.where(id: ids).order('id ASC')
    prepare_db_and_tables(db_name)
    export_words
    export_layouts
    add_db_indexes
  end

  def export_stats
    stats
  end

  protected

  def export_words
    words = []
    page_size = 1000
    i = 0
    stats[:words_count] = 0
    stats[:issues] = []

    Word.unscoped.order('word_index ASC').find_each do |word|
      surah, ayah, word_number = word.location.split(':').map(&:to_i)
      text_uthmani = word.text_uthmani
      text_indopak = word.text_qpc_nastaleeq_hafs
      indopak_hanafi = word.text_indopak_nastaleeq
      dk_indopak = word.text_digital_khatt_indopak
      code_v1 = word.code_v1
      text_digital_khatt_v2 = word.text_digital_khatt
      text_digital_khatt_v1 = word.text_digital_khatt_v1
      text_qpc_hafs = word.text_qpc_hafs
      is_ayah_marker = word.ayah_mark?

      script_texts = [text_uthmani, text_indopak, indopak_hanafi, dk_indopak, code_v1, text_digital_khatt_v2, text_digital_khatt_v1, text_qpc_hafs]
      if script_texts.detect(&:blank?)
        stats[:issues].push("One of script text is blank for word: #{word.location}")
      end

      words.push("(#{surah}, #{ayah}, #{word_number}, #{word.word_index}, '#{text_uthmani}', '#{text_indopak}', '#{indopak_hanafi}', '#{dk_indopak}', '#{code_v1}', '#{text_digital_khatt_v2}', '#{text_digital_khatt_v1}', '#{text_qpc_hafs}', #{is_ayah_marker})")
      i += 1
      stats[:words_count] += 1

      if i >= page_size
        bulk_insert_words(words)
        words = []
        i = 0
      end
    end

    bulk_insert_words(words) if words.present?
  end

  def export_layouts
    exported_tables = {}

    mushafs.each do |mushaf|
      table_name = get_mushaf_file_name(mushaf.id)
      next if exported_tables[table_name]

      exported_tables[table_name] = true
      ExportedLayout.table_name = table_name
      batch_size = 1000
      layout_records = []

      mushaf.mushaf_pages.order("page_number ASC").each do |page|
        lines = {}
        page_alignment = MushafLineAlignment.where(
          mushaf_id: mushaf.id,
          page_number: page.page_number,
        ).order('line_number ASC')

        page_alignment.each do |alignment|
          lines[alignment.line_number.to_i] ||= []
        end

        page.words.includes(:word).order('position_in_page ASC').each do |w|
          lines[w.line_number] ||= []
          lines[w.line_number].push(w.word)
        end

        lines.keys.sort.each_with_index do |line, index|
          alignment = MushafLineAlignment.where(
            mushaf_id: mushaf.id,
            page_number: page.page_number,
            line_number: line
          ).first

          line_type = if alignment
                        if alignment.is_surah_name?
                          'surah_name'
                        elsif alignment.is_bismillah?
                          'basmallah'
                        else
                          'ayah'
                        end
                      else
                        'ayah'
                      end

          range_start = range_end = nil
          if line_type == 'ayah' && lines[line].present?
            words = lines[line].sort_by { |word| word.word_index }

            range_start = words.first.word_index
            range_end = words.last.word_index
          elsif line_type == 'surah_name'
            range_start = alignment.get_surah_number
          end

          is_centered = alignment&.is_center_aligned? || line_type == 'surah_name' || line_type == 'basmallah'

          layout_records << [
            page.page_number,
            index + 1,
            line_type,
            is_centered,
            range_start,
            range_end
          ]

          if layout_records.size >= batch_size
            bulk_insert_layouts(layout_records)
            layout_records = []
          end
        end
      end

      bulk_insert_layouts(layout_records) unless layout_records.empty?
      prepare_layout_stats(mushaf, table_name)
    end
  end

  def bulk_insert_layouts(layout_records)
    values = layout_records.map do |record|
      "(#{record[0]}, #{record[1]}, '#{record[2]}', #{record[3] ? 'TRUE' : 'FALSE'}, #{record[4] ? record[4] : 'NULL'}, #{record[5] ? record[5] : 'NULL'})"
    end.join(", ")

    ExportedLayout.connection.execute <<-SQL
  INSERT INTO #{ExportedLayout.table_name} (
    page,
    line,
    type,
    is_centered,
    range_start,
    range_end
  ) VALUES
    #{values}
    SQL
  end

  def get_mushaf_file_name(mushaf_id)
    mapping = {
      "1": "qpc_v2_layout",
      "2": "qpc_v1_layout",
      "3": "indopak_layout",

      # 4-12 has same layout
      "4": "qpc_hafs_15_lines_layout",
      "5": "qpc_hafs_15_lines_layout",
      "10": "qpc_hafs_15_lines_layout",
      "11": "qpc_hafs_15_lines_layout",
      "12": "qpc_hafs_15_lines_layout",

      "6": "indopak_15_lines_layout",
      "7": "indopak_16_lines_layout",
      "8": "indopak_14_lines_layout",
      "14": "indopak_madani_15_lines_layout",
      "16": "qpc_hafs_tajweed_15_lines_layout",
      "17": "indopak_13_lines_layout",
      "19": "qpc_v4_layout",
      "20": "qpc_v2_layout",
      "21": "qpc_tajweed_layout",
      "22": "qpc_v1_layout"
    }

    mapping[mushaf_id.to_s.to_sym]
  end

  def prepare_db_and_tables(db)
    ExportedWord.establish_connection(
      { adapter: 'sqlite3',
        database: db
      })
    ExportedLayout.establish_connection(
      { adapter: 'sqlite3',
        database: db
      })

    ExportedWord.connection.execute "CREATE TABLE words(surah_number integer, ayah_number integer, word_number integer, word_number_all integer, uthmani string, nastaleeq string, indopak string, dk_indopak string, qpc_v1 string, dk_v2 string, dk_v1 string, qpc_hafs string, is_ayah_marker boolean)"
    layout_created = {}

    mushafs.each do |mushaf|
      db_name = get_mushaf_file_name(mushaf.id)
      next if layout_created[db_name]

      layout_created[db_name] = true
      stats[:exported_layouts] ||= {}
      stats[:exported_layouts][db_name] = {}

      ExportedLayout.connection.execute "CREATE TABLE #{db_name}(page integer, line integer, type text, is_centered boolean, range_start integer, range_end integer)"
    end
  end

  def add_db_indexes
    ExportedWord.connection.execute "CREATE UNIQUE INDEX idx_words_word_number_all ON words(word_number_all)"
    ExportedWord.connection.execute "CREATE INDEX idx_words_surah_ayah ON words(surah_number, ayah_number)"

    # mushafs.each do |mushaf|
    #  tbl_name = get_mushaf_file_name(mushaf.id)
    #  ExportedLayout.connection.execute "CREATE INDEX #{tbl_name}_page ON #{tbl_name}(page)"
    #  ExportedLayout.connection.execute "CREATE INDEX #{tbl_name}_line ON #{tbl_name}(line)"
    # end
  end

  def bulk_insert_words(values)
    # nastaleeq is indopak script printed in Madaniah and compatible with QPC font
    ExportedWord.connection.execute <<-SQL
  INSERT INTO words (
    surah_number,
    ayah_number,
    word_number,
    word_number_all,
    uthmani,
    nastaleeq, 
    indopak,
    dk_indopak,
    qpc_v1,
    dk_v2,
    dk_v1, 
    qpc_hafs,
    is_ayah_marker
  ) VALUES
    #{values.join(',')}
    SQL
  end

  def prepare_layout_stats(mushaf, table_name)
    page_count = mushaf.mushaf_pages.count
    exported_words_count = 0
    exported_page_count = ExportedLayout.connection.execute("SELECT COUNT(DISTINCT page) FROM #{table_name}").first[0]

    ExportedLayout.where(type: 'ayah').each do |line|
      next if line.range_start.nil? || line.range_end.nil?
      page_words = line.range_end - line.range_start + 1
      exported_words_count += page_words
    end

    layout_stats = stats[:exported_layouts][table_name] || {}
    stats[:exported_layouts][table_name] = {
      surah_name_lines: ExportedLayout.where(type: 'surah_name').count + layout_stats[:surah_name_lines].to_i,
      basmallah_lines: ExportedLayout.where(type: 'basmallah').count + layout_stats[:basmallah_lines].to_i,
      ayah_lines: ExportedLayout.where(type: 'ayah').count + layout_stats[:ayah_lines].to_i,
      total_lines: ExportedLayout.count + layout_stats[:total_lines].to_i,
      mushaf_page_count: page_count + layout_stats[:mushaf_page_count].to_i,
      exported_words_count: exported_words_count + layout_stats[:exported_words_count].to_i,
      exported_page_count: exported_page_count + layout_stats[:exported_page_count].to_i
    }

    stats[:exported_layouts][table_name][:issues] ||= []
    layout_stats = stats[:exported_layouts][table_name]

    if layout_stats[:surah_name_lines] != 114
      layout_stats[:issues].push("Surah name lines count is not 114")
    end

    # Some page could have fewer lines, like last page.
    # TODO: fix the line count validation
    if layout_stats[:total_lines] != mushaf.total_lines
      layout_stats[:issues].push("Total lines count is not equal to mushaf lines count")
    end

    if layout_stats[:exported_words_count] != Word.count
      layout_stats[:issues].push("Exported words count is not equal to total words count")
    end

    if layout_stats[:exported_page_count] != mushaf.pages_count
      layout_stats[:issues].push("Exported page should be equal to mushaf page count")
    end

    if layout_stats[:basmallah_lines] != 112
      layout_stats[:issues].push("Basmallah lines count is not 112")
    end
  end
end
