class ExportMushafLayout
  MUSHAF_IDS = [
    2, # v1
    1, # v2
    5, # KFGQPC HAFS
    6, # Indopak 15 lines
    # 7, # Indopak 16 lines surah name and bismillah is one the same line for some pages
    # 8, # Indopak 14 lines Pak company has wrong line alignments data
    16, # QPC Hafs with tajweed
    17, # Indopak 13 lines
    20, # Digital Khatt
  ]
  attr_accessor :mushafs

  def export(ids=MUSHAF_IDS, db_name="quran-data.sqlite")
    @mushafs = Mushaf.where(id: ids).order('id ASC')
    prepare_db_and_tables(db_name)
    export_words
    export_layout
    # add_db_indexes
  end

  protected

  class ExportedWord < ApplicationRecord
  end

  class ExportedLayout < ApplicationRecord
    self.inheritance_column = nil
  end

  def export_words
    words = []
    page_size = 1000
    i = 0

    Word.unscoped.order('word_index ASC').find_each do |word|
      surah, ayah, word_number = word.location.split(':').map(&:to_i)
      text_uthmani = word.text_uthmani
      text_indopak = word.text_qpc_nastaleeq_hafs
      indopak_hanafi = word.text_indopak_nastaleeq
      code_v1 = word.code_v1
      text_digital_khatt = word.text_digital_khatt
      text_qpc_hafs = word.text_qpc_hafs
      is_ayah_marker = word.ayah_mark?

      words.push("(#{surah}, #{ayah}, #{word_number}, #{word.word_index}, '#{text_uthmani}', '#{text_indopak}', '#{indopak_hanafi}', '#{code_v1}', '#{text_digital_khatt}', '#{text_qpc_hafs}', #{is_ayah_marker})")
      i += 1

      if i >= page_size
        bulk_insert_words(words)
        words = []
        i = 0
      end
    end

    bulk_insert_words(words) if words.present?
  end

  def export_layouts
    mushafs.each do |mushaf|
      table_name = get_mushaf_file_name(mushaf.id)
      ExportedLayout.table_name = table_name

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
          end

          ExportedLayout.create(
            page: page.page_number,
            line: index + 1,
            type: line_type,
            is_centered: !!alignment&.is_center_aligned?,
            range_start: range_start,
            range_end: range_end
          )
        end
      end
    end
  end

  def export_layout
    mushafs.each do |mushaf|
      table_name = get_mushaf_file_name(mushaf.id)
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
      "5": "qpc_hafs_15_lines_layout",
      "6": "indopak_15_lines_layout",
      "7": "indopak_16_lines_layout",
      "8": "indopak_14_lines_layout",
      "14": "indopak_madani_15_lines_layout",
      "16": "qpc_hafs_tajweed_15_lines_layout",
      "17": "indopak_13_lines_layout",
      "20": "digital_khatt_layout",
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

    ExportedWord.connection.execute "CREATE TABLE words(surah_number integer, ayah_number integer, word_number integer, word_number_all integer, uthmani string, nastaleeq string, indopak string, qpc_v1 string, dk string, qhc_hafs string, is_ayah_marker boolean)"

    mushafs.each do |mushaf|
      db_name = get_mushaf_file_name(mushaf.id)
      ExportedLayout.connection.execute "CREATE TABLE #{db_name}(page integer, line integer, type text, is_centered boolean, range_start integer, range_end integer)"
    end
  end

  def export_word(surah, ayah, word_number, word_index, text_uthmani, text_indopak, indopak_hanafi, code_v1, text_digital_khatt, text_qpc_hafs, is_ayah_number)
    ExportedWord.connection.execute <<-SQL
    INSERT INTO words (
      surah_number,
      ayah_number,
      word_number,
      word_number_all,
      uthmani,
      nastaleeq,
      indopak,
      qpc_v1,
      dk,
      qhc_hafs,
      is_ayah_marker
    ) VALUES (
      #{surah},
      #{ayah},
      #{word_number},
      #{word_index},
      '#{text_uthmani}',
      '#{text_indopak}',
      '#{indopak_hanafi}'
      '#{code_v1}',
      '#{text_digital_khatt}',
      '#{text_qpc_hafs}',
      #{is_ayah_number}
    )
    SQL
  end

  def add_db_indexes
    ExportedWord.connection.execute "CREATE INDEX words_surah_number ON words(surah_number)"
    ExportedWord.connection.execute "CREATE INDEX words_ayah_number ON words(ayah_number)"
    ExportedWord.connection.execute "CREATE INDEX words_word_number ON words(word_number)"
    ExportedWord.connection.execute "CREATE INDEX words_word_index ON words(word_number_all)"

    mushafs.each do |mushaf|
      tbl_name = get_mushaf_file_name(mushaf.id)
      ExportedLayout.connection.execute "CREATE INDEX #{tbl_name}_page ON #{tbl_name}(page)"
      ExportedLayout.connection.execute "CREATE INDEX #{tbl_name}_line ON #{tbl_name}(line)"
    end
  end

  def bulk_insert_words(values)
    ExportedWord.connection.execute <<-SQL
  INSERT INTO words (
    surah_number,
    ayah_number,
    word_number,
    word_number_all,
    uthmani,
    nastaleeq,
    indopak,
    qpc_v1,
    dk,
    qhc_hafs,
    is_ayah_marker
  ) VALUES
    #{values.join(',')}
    SQL
  end
end
