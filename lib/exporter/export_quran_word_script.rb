module Exporter
  class ExportQuranWordScript < BaseExporter
    def initialize(resource_content:, base_path:)
      super(base_path: base_path, name: resource_content.sqlite_file_name)
      @resource_content = resource_content
    end

    def export_sqlite
      db_file_path = "#{@export_file_path}.db"

      statement = create_sqlite_table(db_file_path, 'words', words_table_columns)
      text_attribute = @resource_content.meta_value('text_type')

      words.each do |batch|
        batch.each do |w|
          export_word(w, statement, text_attribute)
        end
      end

      close_sqlite_table

      db_file_path
    end

    def export_json
      json_file_path = "#{@export_file_path}.json"

      json_data = {}
      text_attribute = @resource_content.meta_value('text_type')

      words.each do |batch|
        batch.each do |w|
          json_data[w.location] = {
            word_index: w.word_index,
            location: w.location,
            text: w.send(text_attribute)
          }
        end
      end

      File.open(json_file_path, 'wb') do |file|
        file << JSON.generate(json_data, { state: JsonNoEscapeHtmlState.new })
      end

      json_file_path
    end

    protected

    def words
      Word.unscoped.order('word_index asc').in_batches(of: 1000)
    end

    def export_word(word, statement, text_attribute)
      statement.execute([word.word_index, word.location, word.send(text_attribute)])
    end

    def words_table_columns
      {
        word_index: 'INTEGER',
        word_key: 'TEXT',
        text: 'TEXT'
      }
    end
  end
end