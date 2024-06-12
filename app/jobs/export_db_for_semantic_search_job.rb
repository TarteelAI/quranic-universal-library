class ExportDbForSemanticSearchJob < ApplicationJob
  queue_as :default
  STORAGE_PATH = "public/assets/exported_databses"

  def perform(file_name)
    file_path = STORAGE_PATH
    require 'fileutils'
    FileUtils::mkdir_p STORAGE_PATH
    ActiveRecord::Base.logger = nil

    prepare_db("#{file_path}/#{file_name}.db")

    approved_translations = ResourceContent.translations.approved.pluck(:id)

    Word.order('verse_id asc, position asc').find_in_batches do |words|
      ExportRecord.connection.execute("INSERT INTO words (id, verse_id, chapter_id, position, text_madani, text_indopak, text_imlaei, text_madani_simple, text_imlaei_simple, verse_key, char_type_name)
                                     VALUES #{prepare_words_import_sql(words)}")
    end

    Translation.where(resource_content_id: approved_translations).find_in_batches do |translations|
      ExportRecord.connection.execute("INSERT INTO translations (id, verse_id, text, language_name, author_name)
                                     VALUES #{prepare_translation_import_sql(translations)}")
    end


    WordTranslation.order('word_id asc').find_in_batches do |words|
      ExportRecord.connection.execute("INSERT INTO word_translations (id, word_id, text, language_name)
                                     VALUES #{prepare_words_translations_import_sql(words)}")
    end

    ExportRecord.connection.execute("INSERT INTO verses (id, verse_number, chapter_id, verse_key, text_madani, text_indopak, text_imlaei, text_madani_simple, text_imlaei_simple)
                                     VALUES #{prepare_ayah_import_sql(Verse.all)}")




    # zip the file
    `bzip2 #{file_path}/#{file_name}.db`

    # return the db file path
    "#{file_path}/#{file_name}.db.bz2"
  end

  def prepare_db(file_path)
    ExportRecord.establish_connection connection_config(file_path)
    ExportRecord.connection.execute "CREATE TABLE verses( id integer, verse_number integer, chapter_id integer, verse_key text, text_madani text, text_indopak text, text_imlaei text, text_madani_simple text, text_imlaei_simple text)"
    ExportRecord.connection.execute "CREATE TABLE words( id integer, verse_id integer, chapter_id integer, position integer, text_madani text, text_indopak text, text_imlaei text, text_madani_simple text, text_imlaei_simple text, verse_key text, char_type_name text)"
    ExportRecord.connection.execute "CREATE TABLE translations( id integer, verse_id integer, text text, language_name text, author_name text)"
    ExportRecord.connection.execute "CREATE TABLE word_translations( id integer, word_id integer, text text, language_name text)"

    ExportVerseRecord.table_name = 'verses'
    ExportWordRecord.table_name = 'words'
    ExportTranslationRecord.table_name = 'translations'
    ExportWordTranslationRecord.table_name = 'word_translations'
  end

  def prepare_ayah_import_sql(verses)
    verses.map do |v|
      "(#{v.id}, #{v.verse_number}, #{v.chapter_id}, #{format_text v.verse_key}, #{format_text v.text_uthmani}, #{format_text v.text_indopak}, #{format_text v.text_imlaei}, #{format_text v.text_uthmani_simple}, #{format_text v.text_simple})"
    end.join(',')
  end

  def prepare_translation_import_sql(translations)
    translations.map do |t|
      "(#{t.id}, #{t.verse_id}, #{format_text t.text}, #{format_text((t.language_name.presence || t.language.name).to_s.downcase)}, #{format_text t.resource_name})"
    end.join(',')
  end

  def prepare_words_import_sql(words)
    words.map do |w|
      "(#{w.id}, #{w.verse_id}, #{w.chapter_id}, #{w.position}, #{format_text w.text_uthmani}, #{format_text w.text_indopak}, #{format_text w.text_imlaei}, #{format_text w.text_uthmani_simple}, #{format_text w.text_simple}, #{format_text w.verse_key}, #{format_text w.char_type_name})"
    end.join(',')
  end

  def prepare_words_translations_import_sql(translations)
    translations.map do |t|
      "(#{t.id}, #{t.word_id}, #{format_text t.text}, #{format_text((t.language_name.presence || t.language.name).to_s.downcase)})"
    end.join(',')
  end

  def format_text(text)
    ExportRecord.connection.quote(text)
  end

  def connection_config(file_name)
    {adapter: 'sqlite3',
     database: file_name
    }
  end

  class ExportRecord < ActiveRecord::Base
  end

  class ExportVerseRecord < ExportRecord
  end

  class ExportWordRecord < ExportRecord
  end

  class ExportTranslationRecord < ExportRecord
  end

  class ExportWordTranslationRecord < ExportRecord
  end
end
