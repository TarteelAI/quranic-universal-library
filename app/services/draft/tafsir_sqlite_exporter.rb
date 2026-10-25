# frozen_string_literal: true

# Dump draft tafsirs of a resource to a sqlite db file so they can be moved
# between environments(e.g from local to staging/production).
#
# Ayahs are referenced by verse_key instead of verse_id to keep the dump
# portable, verse ids are not guaranteed to be same across environments.
#
#   path = Draft::TafsirSqliteExporter.new(resource_content).export
module Draft
  class TafsirSqliteExporter
    SCHEMA_VERSION = 1
    STORAGE_PATH = "#{Rails.root}/tmp/exported_databases/draft_tafsirs"
    BATCH_SIZE = 500

    attr_reader :resource_content, :file_path

    def initialize(resource_content)
      @resource_content = resource_content
    end

    def export
      require 'sqlite3'
      FileUtils.mkdir_p(STORAGE_PATH)

      FileUtils.rm_f(file_name)
      @file_path = file_name

      db = SQLite3::Database.new(file_path)

      begin
        create_tables(db)
        insert_properties(db)
        insert_tafsirs(db)
      ensure
        db.close
      end

      file_path
    end

    def file_name
      name = resource_content.slug.presence || "draft-tafsir-#{resource_content.id}"

      "#{STORAGE_PATH}/#{name}-draft-#{Time.now.strftime('%Y-%m-%d')}.db".gsub(/\s+/, '')
    end

    protected

    def create_tables(db)
      db.execute <<-SQL
        CREATE TABLE tafsirs(
          verse_key TEXT,
          group_verse_key_from TEXT,
          group_verse_key_to TEXT,
          group_verses_count INTEGER,
          start_verse_key TEXT,
          end_verse_key TEXT,
          group_tafsir_verse_key TEXT,
          draft_text TEXT,
          text_matched INTEGER,
          need_review INTEGER,
          reviewed INTEGER,
          imported INTEGER,
          comments TEXT,
          meta_data TEXT
        )
      SQL

      db.execute "CREATE TABLE properties(property TEXT, value TEXT)"
      db.execute "CREATE INDEX index_tafsirs_on_verse_key ON tafsirs(verse_key)"
    end

    def insert_properties(db)
      properties = {
        schema_version: SCHEMA_VERSION,
        resource_content_id: resource_content.id,
        resource_name: resource_content.name,
        language_name: resource_content.language_name,
        cardinality_type: resource_content.cardinality_type,
        records_count: scope.count,
        exported_at: Time.now.utc.iso8601
      }

      properties.each do |property, value|
        db.execute("INSERT INTO properties(property, value) VALUES (?, ?)", [property.to_s, value.to_s])
      end
    end

    def insert_tafsirs(db)
      verses = Verse.pluck(:id, :verse_key).to_h

      statement = db.prepare <<-SQL
        INSERT INTO tafsirs(
          verse_key, group_verse_key_from, group_verse_key_to, group_verses_count,
          start_verse_key, end_verse_key, group_tafsir_verse_key, draft_text,
          text_matched, need_review, reviewed, imported, comments, meta_data
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      SQL

      db.transaction do
        scope.find_each(batch_size: BATCH_SIZE) do |draft|
          statement.execute(
            verses[draft.verse_id],
            draft.group_verse_key_from,
            draft.group_verse_key_to,
            draft.group_verses_count,
            verses[draft.start_verse_id],
            verses[draft.end_verse_id],
            verses[draft.group_tafsir_id],
            draft.draft_text,
            bool(draft.text_matched),
            bool(draft.need_review),
            bool(draft.reviewed),
            bool(draft.imported),
            draft.comments,
            draft.meta_data.presence && JSON.generate(draft.meta_data)
          )
        end
      end

      statement.close
    end

    def scope
      Draft::Tafsir
        .where(resource_content_id: resource_content.id)
        .order('verse_id ASC')
    end

    def bool(value)
      value ? 1 : 0
    end
  end
end
