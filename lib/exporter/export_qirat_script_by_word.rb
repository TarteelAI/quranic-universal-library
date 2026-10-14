module Exporter
  class ExportQiratScriptByWord < BaseExporter
    def initialize(resource_content:, base_path:)
      super(
        base_path: base_path,
        resource_content: resource_content
      )

      @resource_content = resource_content
    end

    def export_sqlite
      db_file_path = "#{@export_file_path}.db"

      statement = create_sqlite_table(db_file_path, 'words', words_table_columns)

      words.each do |batch|
        batch.each do |word|
          export_word(word, statement)
        end
      end

      close_sqlite_table

      db_file_path
    end

    def export_json
      json_file_path = "#{@export_file_path}.json"

      json_data = {}

      words.each do |batch|
        batch.each do |word|
          json_data[word.key] = {
            id: word.id,
            surah: word.chapter_id,
            ayah: word.verse_number,
            word: word.word_number,
            location: word.key,
            text: word.text
          }
        end
      end

      File.open(json_file_path, 'wb') do |file|
        file << JSON.generate(json_data, { state: JsonNoEscapeHtmlState.new })
      end

      json_file_path
    end

    protected

    # Source selection through scripts (P3.7): a row-backed script exports its
    # word_texts keyed by the Kufi word location and the shared number; a legacy
    # script (or a resource with no script row) exports the raw legacy rows.
    def script
      @script ||= Script.for_resource_content(@resource_content)
    end

    def words
      if script&.rows?
        WordText.where(script_id: script.id)
                .joins(:word).merge(Word.unscoped.order(:verse_id, :position, :sub_position))
                .includes(:word)
                .in_batches(of: 1000)
      else
        QuranScript::ByWord
          .where(resource_content_id: @resource_content.id)
          .order('chapter_id asc, verse_number asc, word_number asc')
          .in_batches(of: 1000)
      end
    end

    def export_word(word, statement)
      statement.execute(word_row(word))
    end

    def word_row(word)
      if word.is_a?(WordText)
        w = word.word
        [w.id, w.location, w.chapter_id, w.verse.verse_number, w.position, word.text]
      else
        [word.id, word.key, word.chapter_id, word.verse_number, word.word_number, word.text]
      end
    end

    def words_table_columns
      {
        id: 'INTEGER',
        location: 'TEXT',
        surah: 'INTEGER',
        ayah: 'INTEGER',
        word: 'INTEGER',
        text: 'TEXT'
      }
    end
  end
end
