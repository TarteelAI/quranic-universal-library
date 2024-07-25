module Exporter
  class ExportWordTransliteration < BaseExporter
    attr_accessor :resource_content

    def initialize(resource_content:, base_path:)
      super(base_path: base_path, name: resource_content.sqlite_file_name)
      @resource_content = resource_content
    end

    def export_json
      @json_data = {}
      json_file_path = "#{export_file_path}.json"

      records.find_each do |translation|
        @json_data[translation.resource.location] =  translation.text
      end

      File.open(json_file_path, 'wb') do |file|
        file << JSON.generate(@json_data, { state: JsonNoEscapeHtmlState.new })
      end

      json_file_path
    end

    def export_sqlite(table_name= 'word_transliteration')
      db_file_path = "#{@export_file_path}.db"
      statement = create_sqlite_table(db_file_path, table_name, sqlite_db_columns)

      records.each do |translation|
        surah, ayah, word = translation.resource.location.split(':')
        fields = [surah, ayah, word, translation.text]
        statement.execute(fields)
      end

      close_sqlite_table

      db_file_path
    end

    protected

    def sqlite_db_columns
      {
        surah_number: 'INTEGER',
        ayah_number: 'INTEGER',
        word_number: 'TEXT',
        text: 'TEXT',
      }
    end

    def records
      Transliteration.where(resource_type: 'Word', resource_content_id: resource_content.id)
    end
  end
end