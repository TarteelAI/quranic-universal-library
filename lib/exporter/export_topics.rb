module Exporter
  class ExportTopics < BaseExporter
    attr_accessor :resource_content

    def initialize(resource_content:, base_path:)
      super(base_path: base_path, name: resource_content.sqlite_file_name)
      @resource_content = resource_content
    end

    def export_sqlite(table_name= 'topics')
      db_file_path = "#{@export_file_path}.db"
      statement = create_sqlite_table(db_file_path, table_name, sqlite_db_columns)

      records.each do |record|
        fields = [
          record.id,
          record.name,
          record.arabic_name,
           record.parent_id,
          record.thematic_parent_id,
           record.ontology_parent_id,
          record.description,
          record.wikipedia_link,
          record.thematic? ? 1 : 0,
          record.ontology? ? 1 : 0,
          record.ayah_keys.join(', '),
          record.related_topics.pluck(:related_topic_id).join(',')
        ]
        statement.execute(fields)
      end

      close_sqlite_table

      db_file_path
    end

    protected

    def sqlite_db_columns
      {
        topic_id: 'INTEGER PRIMARY KEY',
        name: 'TEXT',
        arabic_name: 'TEXT',
        parent_id: 'INTEGER',
        thematic_parent_id: 'INTEGER',
        ontology_parent_id: 'INTEGER',
        description: 'TEXT',
        wiki_link: 'TEXT',
        thematic: 'INTEGER',
        ontology: 'INTEGER',
        ayahs: 'TEXT',
        related_topics: 'TEXT'
      }
    end

    def records
      Topic
        .eager_load(verse_topics: :verse)
    end
  end
end