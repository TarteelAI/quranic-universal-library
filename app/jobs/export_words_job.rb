class ExportWordsJob < ApplicationJob
  queue_as :default
  STORAGE_PATH = "#{Rails.root}/tmp/exported_databses"

  def perform(file_name:, user_id:, mushaf_id: nil, language_id: nil, word_fields: [])
    require 'fileutils'

    file_name = file_name.chomp('.db')
    file_path = "#{STORAGE_PATH}/#{Time.now.to_i}"
    FileUtils::mkdir_p file_path

    prepare_db("#{file_path}/#{file_name}.db", mushaf_id, word_fields, language_id)
    export_db(mushaf_id, word_fields, language_id)

    # zip the file
    `bzip2 #{file_path}/#{file_name}.db`

    zip_path = "#{file_path}/#{file_name}.db.bz2"
    send_email(user_id, zip_path)

    # return the db file path
    zip_path
  end

  protected

  def prepare_db(file_path, mushaf_id, word_fields, language_id)
    ExportRecord.establish_connection connection_config(file_path)
    columns = [
      'sura integer',
      'ayah integer',
      'position integer'
    ]

    if mushaf_id
      columns += ['char_type text', 'text text']
    end

    word_fields.each do |field|
      columns << "#{field} text"
    end

    if language_id.present?
      columns << 'translation text'
    end

    ExportRecord.connection.execute("CREATE TABLE words(#{columns.join(', ')} ,primary key(sura, ayah, position))")
    ExportRecord.table_name = 'words'
  end

  def export_db(mushaf_id, word_fields, language_id)
    db_columns = db_columns_to_export(mushaf_id, word_fields, language_id)
    verses = load_verses(mushaf_id, language_id)

    verses.each do |verse|
      puts "Exporting #{verse.verse_key}"
      export_verse(db_columns, verse, mushaf_id, word_fields, language_id)
    end
  end

  def export_verse(db_columns, verse, mushaf_id, word_fields, language_id)
    chapter_number, verse_number = verse.verse_key.split(':')

    verse.mushaf_words.each do |word|
      position = word.position_in_verse
      values = [chapter_number, verse_number, position]

      if mushaf_id
        char_type = ExportRecord.connection.quote(word.char_type_name)
        text = ExportRecord.connection.quote(word.text)

        values += [char_type, text]
      end

      if word_fields.include?('audio_url')
        location = values.map { |val| val.to_s.rjust(3, '0') }.join('_')
        values << ExportRecord.connection.quote("wbw/#{location}.mp3")
      end

      if language_id.present?
        translation = ExportRecord.connection.quote(word.word_translation.text)
        values << translation
      end

      ExportRecord.connection.execute("INSERT INTO words (#{db_columns}) VALUES (#{values.join(', ')})")
    end
  end

  def send_email(user_id, zip_path)
    DeveloperMailer.notify(
      to: User.find(user_id).email,
      subject: "Words dump file",
      message: "Please see the attached dump file",
      file_path: zip_path
    ).deliver_now
  end

  def load_verses(mushaf_id, language_id)
    mushaf_type = mushaf_id || Mushaf.where(is_default: true).first.id

    verses = Verse

    if language_id.present?
      with_default_translation = verses.where(word_translations: { language_id: Language.default.id })

      verses = verses
                 .where(word_translations: { language_id: language_id })
                 .or(with_default_translation)
                 .eager_load(mushaf_words: :word_translation)
                 .order('verse_id ASC, mushaf_words.position_in_verse ASC, word_translations.priority ASC')
    else
      verses = verses.eager_load(:mushaf_words).order('verse_id ASC, mushaf_words.position_in_verse ASC')
    end

    verses.where(mushaf_words: { mushaf_id: mushaf_type })
  end

  def db_columns_to_export(mushaf_id, word_fields, language_id)
    columns = [
      'sura',
      'ayah',
      'position'
    ]

    if mushaf_id.present?
      columns += ['char_type', 'text']
    end

    columns += word_fields

    if language_id.present?
      columns << 'translation'
    end

    columns.join(', ')
  end

  def connection_config(file_name)
    { adapter: 'sqlite3',
      database: file_name
    }
  end

  class ExportRecord < ActiveRecord::Base
  end
end
