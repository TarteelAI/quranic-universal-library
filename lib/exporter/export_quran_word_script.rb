module Exporter
  class ExportQuranWordScript < BaseExporter
    def initialize(resource_content:, base_path:)
      super(base_path: base_path, resource_content: resource_content)
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
        batch.each do |word|
          s, a, w = word.location.split(':')

          data = {
            id: word.word_index,
            surah: s,
            ayah: a,
            word: w,
            location: word.location,
            text: word.send(text_attribute)
          }

          json_data[word.location] = data
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
      s, a, w = word.location.split(':')
      data = [
        word.word_index,
        word.location,
        s,
        a,
        w,
        word.send(text_attribute)
      ]

      statement.execute(data)
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