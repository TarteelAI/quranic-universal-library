 namespace :export_quranic_script do
  task run: :environment do
    class Words < ActiveRecord::Base
      self.table_name = "words"
      self.primary_key = "id"
    end

    class Ayah < ActiveRecord::Base
      self.table_name = "verses"
      self.primary_key = "id"
    end

    def prepare_db_and_tables(file_name)
      Ayah.establish_connection({ adapter: 'sqlite3',
                                   database: "pendu_devs.db"
                                 })

      Ayah.connection.execute "CREATE TABLE students(id integer, name string, joining_date date, email )"

      Ayah.establish_connection({ adapter: 'sqlite3',
                                  database: file_name
                                })

      Ayah.connection.execute "CREATE TABLE verses(id integer, surah_number integer, ayah_number string, key string, text_uthmani string, text_uthmani_simple string, text_indopak string, text_imlaei string, text_imlaei_simple string, text_qpc_hafs string)"
    end

    prepare_db_and_tables "quranic_script.db"

    Verse.order('verse_index ASC').each do |ayah|
      Ayah.create(
        id: ayah.id,
        surah_number: ayah.chapter_id,
        ayah_number: ayah.verse_number,
        key: ayah.verse_key,
        text_uthmani: ayah.text_uthmani,
        text_uthmani_simple: ayah.text_imlaei_simple,
        text_indopak: ayah.text_indopak,
        text_imlaei: ayah.text_imlaei,
        text_imlaei_simple: ayah.text_imlaei_simple,
        text_qpc_hafs: ayah.text_qpc_hafs
      )

      ayah.words.each do |w|
        s, a, p = w.location.split(':')
        Words.create(
          id: w.id,
          surah_number: s,
          ayah_number: a,
          position: p,
          location: w.location,
          word_type: w.char_type_name,
          text_uthmani: w.text_uthmani,
          text_uthmani_simple: w.text_uthmani_simple,
          text_indopak: w.text_indopak,
          text_imlaei: w.text_imlaei,
          text_imlaei_simple: w.text_imlaei_simple,
          text_qpc_hafs: w.text_qpc_hafs
        )
      end
    end
  end
end