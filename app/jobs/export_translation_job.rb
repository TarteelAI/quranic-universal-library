class ExportTranslationJob < ApplicationJob
  queue_as :default
  STORAGE_PATH = "#{Rails.root}/tmp/exported_databases"

  SEE_MORE_REF_REGEXP = Regexp.new('(\d+:\d+)')
  FOOT_NOTE_REG = /<sup foot_note=["']?(?<footnote_id>\d+)["']?>\d+<\/sup>/
  TAG_SANITIZER = Rails::Html::WhiteListSanitizer.new
  BRIDGRES_FOOTNOTE_MAPPING = {
    sg: 'Singular',
    pl: 'Plural',
    dl: 'Dual'
  }

  attr_reader :include_footnote,
              :file_name,
              :resource_content,
              :whitelisted_tags

  def perform(resource_id, original_file_name, include_footnote = false, user_id = nil)
    @include_footnote = include_footnote
    @resource_content = ResourceContent.find(resource_id)

    setup(original_file_name)
    prepare_sqlite_db_file
    import_data_in_sqlite_db
    compress_sqlite_db_file
    upload_exported_file
    send_email("#{file_name}.bz2", user_id) if user_id.present?

    # return the db file path
    "#{file_name}.bz2"
  end

  protected

  def send_email(zip_path, user_id)
    DeveloperMailer.notify(
      to: User.find(user_id).email,
      subject: "#{@resource_content.name} sqlite export",
      message: "Please see the attached dump file",
      file_path: zip_path
    ).deliver_now
  end

  def setup(original_file_name)
    require 'fileutils'

    name = (original_file_name.presence || @resource_content.sqlite_file_name).chomp('.db')
    timestamp = Time.now
    file_path = "#{STORAGE_PATH}/#{timestamp.to_i}".strip
    FileUtils::mkdir_p file_path

    @file_name = "#{file_path}/#{name}-#{timestamp.strftime('%m-%d-%Y')}.db".gsub(/\s+/, '')

    @whitelisted_tags = if (resource_content.id == 149)
                          [] #%w(span b)
                        else
                          []
                        end
  end

  def prepare_sqlite_db_file
    ExportRecord.establish_connection connection_config(file_name)
    if @resource_content.tafsir?
      ExportRecord.connection.execute "CREATE VIRTUAL TABLE verses using fts3( sura integer, ayah integer, ayah_from text, ayah_to text, verses_count integer, text text)"
    else
      ExportRecord.connection.execute "CREATE VIRTUAL TABLE verses using fts3( sura integer, ayah integer, text text)"
    end

    ExportRecord.connection.execute "CREATE TABLE properties( property text, value text)"
    ExportRecord.connection.execute "INSERT INTO properties(property, value) VALUES ('schema_version', 2), ('text_version', 1)"
    ExportRecord.table_name = 'verses'
  end

  def compress_sqlite_db_file
    # zip the file
    `bzip2 #{file_name}`
  end

  def import_data_in_sqlite_db
    if @resource_content.tafsir?
      ExportRecord.connection.execute("INSERT INTO verses (sura, ayah, ayah_from, ayah_to, verses_count, text)
                                     VALUES #{prepare_import_sql_statements}")
    else
      ExportRecord.connection.execute("INSERT INTO verses (sura, ayah, text)
                                     VALUES #{prepare_import_sql_statements}")
    end
  end

  def upload_exported_file
    UploadTranslationDbJob.perform_later(resource_content, "#{file_name}.bz2")
  end

  def prepare_import_sql_statements
    if resource_content.tafsir?
      sql_statements_for_tafsir
    else
      sql_statements_for_translation
    end.join(',')
  end

  def sql_statements_for_tafsir
    records = Tafsir.where(resource_content_id: resource_content.id).order('verse_id ASC')
    connection = ExportRecord.connection

    groups = []

    records.each do |tafsir|
      if tafsir.group_verses_count == 1
        text = connection.quote(tafsir.text)
        ayah = tafsir.verse_number
        key = connection.quote(tafsir.verse_key)

        groups << "(#{tafsir.chapter_id}, #{ayah}, #{key}, #{key}, 1, #{text})"
      else
        if tafsir.group_tafsir_id == tafsir.id
          text = connection.quote(tafsir.text)
          ayah = tafsir.verse_number
          key_from = connection.quote(tafsir.group_verse_key_from)
          key_to = connection.quote(tafsir.group_verse_key_to)

          groups << "(#{tafsir.chapter_id}, #{ayah}, #{key_from}, #{key_to}, #{tafsir.group_verses_count}, #{text})"
        end
      end
    end

    groups
  end

  def sql_statements_for_translation
    records = Translation.where(resource_content_id: resource_content.id)
                         .order('verse_id ASC')

    records.map do |translation|
      text = format_translation_text(translation)

      "(#{translation.chapter_id}, #{translation.verse_number}, #{text})"
    end
  end

  def format_translation_text(translation)
    text = translation_text(translation)
    sanitized = sanitize_text(text)

    ExportRecord.connection.quote(sanitized)
  end

  def sanitize_text(text)
    sanitized = TAG_SANITIZER.sanitize(text.to_s.strip, tags: whitelisted_tags, attributes: [])

    sanitized.gsub(SEE_MORE_REF_REGEXP) do
      "{#{Regexp.last_match(1)}}"
    end
  end

  def translation_text(translation)
    text = translation.text.gsub('"', '')
    text = fix_bridges_footnotes(text) if is_bridges_translation?(translation)

    if include_footnote
      text.gsub(FOOT_NOTE_REG) do |match|
        if footnote = FootNote.find_by_id($1)&.text
          "[[#{footnote.gsub('"', '')}]]"
        else
          ''
        end
      end
    else
      text.gsub(FOOT_NOTE_REG, '')
    end
  end

  def fix_bridges_footnotes(text)
    docs = Nokogiri::HTML::DocumentFragment.parse(text)

    docs.search("a.sup sup").each do |node|
      t = node.text.strip.to_sym
      if footnote = BRIDGRES_FOOTNOTE_MAPPING[t]
        node.content = "[[#{footnote}]]"
      end
    end

    docs.to_s
  end

  def is_bridges_translation?(translation)
    149 == translation.resource_content_id
  end

  def connection_config(file_name)
    { adapter: 'sqlite3',
      database: file_name
    }
  end

  class ExportRecord < ActiveRecord::Base
  end
end
