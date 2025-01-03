module Exporter
  class ExportQuranWordScript < BaseExporter
    def initialize(resource_content:, base_path:)
      super(base_path: base_path, resource_content: resource_content)
      @resource_content = resource_content

      @page_type = resource_content.meta_value('text_type') == 'code_v1' ? 'page_number' : 'v2_page'
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
            word_index: word.word_index,
            surah: 2,
            ayah: a,
            word: w,
            location: word.location,
            text: word.send(text_attribute)
          }

          if resource_content.glyphs_based?
            data[:page_number] = word.send(@page_type)
          end

          json_data[w.location] = data
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

      if resource_content.glyphs_based?
        data << word.send(@page_type)
      end

      statement.execute(data)
    end

    def words_table_columns
      columns = {
        word_index: 'INTEGER',
        word_key: 'TEXT',
        surah: 'INTEGER',
        ayah: 'INTEGER',
        word: 'INTEGER',
        text: 'TEXT'
      }

      if resource_content.glyphs_based?
        columns[:page_number] = 'INTEGER'
      end

      columns
    end
  end
end