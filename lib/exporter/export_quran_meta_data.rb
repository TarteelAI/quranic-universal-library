module Exporter
  class ExportQuranMetaData < BaseExporter
    attr_accessor :resource_content

    def initialize(resource_content:, base_path:)
      super(base_path: base_path, name: "quran_metadata_#{resource_content.name}")
      @resource_content = resource_content
    end

    def export_json
      send "export_#{resource_type}", format: 'json'
    end

    def export_sqlite
      send "export_#{resource_type}", format: 'sqlite'
    end

    protected
    def resource_type
      name = resource_content.name.gsub(/\s+/, '')
      name.downcase.gsub('name', '').strip
    end

    def export_surah(format:)
      file_path = "#{@export_file_path}.#{format}"

      if format == 'sqlite'
        columns = {
          id: 'INTEGER PRIMARY KEY',
          name: 'TEXT',
          name_simple: 'TEXT',
          name_arabic: 'TEXt',
          revelation_order: 'INTEGER',
          revelation_place: 'TEXT',
          verses_count: 'INTEGER',
          bismillah_pre: 'INTEGER'
        }

        statement = create_sqlite_table(file_path, 'chapters', columns)

        Chapter.order('id asc').each do |chapter|
          statement.execute([
                              chapter.id,
                              chapter.name_complex,
                              chapter.name_simple,
                              chapter.name_arabic,
                              chapter.revelation_order,
                              chapter.revelation_place,
                              chapter.verses_count,
                              chapter.bismillah_pre ? 1 :0
                            ])
        end
      else
        json_data = {}
        Chapter.order('id asc').each do |chapter|
          json_data[chapter.id] = {
            id: chapter.id,
            name: chapter.name_complex,
            name_simple: chapter.name_simple,
            name_arabic: chapter.name_arabic,
            revelation_order: chapter.revelation_order,
            revelation_place: chapter.revelation_place,
            verses_count: chapter.verses_count,
            bismillah_pre: chapter.bismillah_pre
          }
        end

        File.open(file_path, 'w') do |f|
          f << JSON.generate(json_data, { state: JsonNoEscapeHtmlState.new })
        end
      end

      file_path
    end

    def export_ayah(format:)
      file_path = "#{@export_file_path}.#{format}"

      if format == 'sqlite'
        columns = {
          id: 'INTEGER PRIMARY KEY',
          surah_number: 'INTEGER',
          ayah_number: 'INTEGER',
          verse_key: 'TEXT',
          words_count: 'INTEGER',
          text: 'TEXT'
        }

        statement = create_sqlite_table(file_path, 'verses', columns)

        Verse.order('verse_index asc').each do |verse|
          statement.execute([
                              verse.verse_index,
                              verse.chapter_id,
                              verse.verse_number,
                              verse.verse_key,
                              verse.words_count,
                              verse.text_qpc_hafs
                            ])
        end
      else
        json_data = {}
        Verse.order('verse_index asc').each do |verse|
          json_data[verse.id] = {
            id: verse.verse_index,
            surah_number: verse.chapter_id,
            ayah_number: verse.verse_number,
            verse_key: verse.verse_key,
            words_count: verse.words_count,
            text: verse.text_qpc_hafs
          }
        end

        File.open(file_path, 'w') do |f|
          f << JSON.generate(json_data, { state: JsonNoEscapeHtmlState.new })
        end
      end

      file_path
    end

    def export_juz(format:)
      file_path = "#{@export_file_path}.#{format}"

      if format == 'sqlite'
        columns = {
          juz_number: 'INTEGER PRIMARY KEY',
          verses_count: 'INTEGER',
          first_verse_key: 'TEXT',
          last_verse_key: 'TEXT',
          verse_mapping: 'TEXT'
        }

        statement = create_sqlite_table(file_path, 'juz', columns)

        Juz.order('juz_number asc').each do |record|
          statement.execute([
                              record.juz_number,
                              record.verses_count,
                              record.first_verse.verse_key,
                              record.last_verse.verse_key,
                              record.verse_mapping.to_json.gsub(/\s+/, '')
                            ])
        end
      else
        json_data = {}
        Juz.order('juz_number asc').each do |record|
          json_data[record.juz_number] = {
            juz_number: record.juz_number,
            verses_count: record.verses_count,
            first_verse_key: record.first_verse.verse_key,
            last_verse_key: record.last_verse.verse_key,
            verse_mapping: record.verse_mapping
          }
        end

        File.open(file_path, 'w') do |f|
          f << JSON.generate(json_data, { state: JsonNoEscapeHtmlState.new })
        end
      end

      file_path
    end

    def export_hizb(format:)
      file_path = "#{@export_file_path}.#{format}"

      if format == 'sqlite'
        columns = {
          hizb_number: 'INTEGER PRIMARY KEY',
          verses_count: 'INTEGER',
          first_verse_key: 'TEXT',
          last_verse_key: 'TEXT',
          verse_mapping: 'TEXT'
        }

        statement = create_sqlite_table(file_path, 'hizbs', columns)

        Hizb.order('hizb_number asc').each do |record|
          statement.execute([
                              record.hizb_number,
                              record.verses_count,
                              record.first_verse.verse_key,
                              record.last_verse.verse_key,
                              record.verse_mapping.to_json.gsub(/\s+/, '')
                            ])
        end
      else
        json_data = {}
        Hizb.order('hizb_number asc').each do |record|
          json_data[record.hizb_number] = {
            hizb_number: record.hizb_number,
            verses_count: record.verses_count,
            first_verse_key: record.first_verse.verse_key,
            last_verse_key: record.last_verse.verse_key,
            verse_mapping: record.verse_mapping
          }
        end

        File.open(file_path, 'w') do |f|
          f << JSON.generate(json_data, { state: JsonNoEscapeHtmlState.new })
        end
      end

      file_path
    end

    def export_rub(format:)
      file_path = "#{@export_file_path}.#{format}"

      if format == 'sqlite'
        columns = {
          rub_number: 'INTEGER PRIMARY KEY',
          verses_count: 'INTEGER',
          first_verse_key: 'TEXT',
          last_verse_key: 'TEXT',
          verse_mapping: 'TEXT'
        }

        statement = create_sqlite_table(file_path, 'rub', columns)

        RubElHizb.order('rub_el_hizb_number asc').each do |record|
          statement.execute([
                              record.rub_el_hizb_number,
                              record.verses_count,
                              record.first_verse.verse_key,
                              record.last_verse.verse_key,
                              record.verse_mapping.to_json.gsub(/\s+/, '')
                            ])
        end
      else
        json_data = {}
        RubElHizb.order('rub_el_hizb_number asc').each do |record|
          json_data[record.rub_el_hizb_number] = {
            rub_number: record.rub_el_hizb_number,
            verses_count: record.verses_count,
            first_verse_key: record.first_verse.verse_key,
            last_verse_key: record.last_verse.verse_key,
            verse_mapping: record.verse_mapping
          }
        end

        File.open(file_path, 'w') do |f|
          f << JSON.generate(json_data, { state: JsonNoEscapeHtmlState.new })
        end
      end

      file_path
    end

    def export_manzil(format:)
      file_path = "#{@export_file_path}.#{format}"

      if format == 'sqlite'
        columns = {
          manzil_number: 'INTEGER PRIMARY KEY',
          verses_count: 'INTEGER',
          first_verse_key: 'TEXT',
          last_verse_key: 'TEXT',
          verse_mapping: 'TEXT'
        }

        statement = create_sqlite_table(file_path, 'manzil', columns)

        Manzil.order('manzil_number asc').each do |record|
          statement.execute([
                              record.manzil_number,
                              record.verses_count,
                              record.first_verse.verse_key,
                              record.last_verse.verse_key,
                              record.verse_mapping.to_json.gsub(/\s+/, '')
                            ])
        end
      else
        json_data = {}
        Manzil.order('manzil_number asc').each do |record|
          json_data[record.manzil_number] = {
            manzil_number: record.manzil_number,
            verses_count: record.verses_count,
            first_verse_key: record.first_verse.verse_key,
            last_verse_key: record.last_verse.verse_key,
            verse_mapping: record.verse_mapping
          }
        end

        File.open(file_path, 'w') do |f|
          f << JSON.generate(json_data, { state: JsonNoEscapeHtmlState.new })
        end
      end

      file_path
    end

    def export_ruku(format:)
      file_path = "#{@export_file_path}.#{format}"

      if format == 'sqlite'
        columns = {
          ruku_number: 'INTEGER PRIMARY KEY',
          surah_ruku_number: 'INTEGER',
          verses_count: 'INTEGER',
          first_verse_key: 'TEXT',
          last_verse_key: 'TEXT',
          verse_mapping: 'TEXT'
        }

        statement = create_sqlite_table(file_path, 'ruku', columns)

        Ruku.order('ruku_number asc').each do |record|
          statement.execute([
                              record.ruku_number,
                              record.surah_ruku_number,
                              record.verses_count,
                              record.first_verse.verse_key,
                              record.last_verse.verse_key,
                              record.verse_mapping.to_json.gsub(/\s+/, '')
                            ])
        end
      else
        json_data = {}
        Ruku.order('ruku_number asc').each do |record|
          json_data[record.ruku_number] = {
            ruku_number: record.ruku_number,
            surah_ruku_number: record.surah_ruku_number,
            verses_count: record.verses_count,
            first_verse_key: record.first_verse.verse_key,
            last_verse_key: record.last_verse.verse_key,
            verse_mapping: record.verse_mapping
          }
        end

        File.open(file_path, 'w') do |f|
          f << JSON.generate(json_data, { state: JsonNoEscapeHtmlState.new })
        end
      end

      file_path
    end

    def export_sajda(format:)
      file_path = "#{@export_file_path}.#{format}"
      verses = Verse.unscoped.order('sajdah_number asc').where.not(sajdah_number: nil)

      if format == 'sqlite'
        columns = {
          sajdah_number: 'INTEGER PRIMARY KEY',
          verse_key: 'TEXT',
          sajdah_type: 'TEXT'
        }

        statement = create_sqlite_table(file_path, 'sajdah', columns)

        verses.each do |record|
          statement.execute([
                              record.sajdah_number,
                              record.verse_key,
                              record.sajdah_type
                            ])
        end
      else
        json_data = {}
        verses.each do |record|
          json_data[record.sajdah_number] = {
            sajdah_number: record.sajdah_number,
            verse_key: record.verse_key,
            sajdah_type: record.sajdah_type
          }
        end

        File.open(file_path, 'w') do |f|
          f << JSON.generate(json_data, { state: JsonNoEscapeHtmlState.new })
        end
      end

      file_path
    end
  end
end