module Exporter
  class ExportQuranicMorphology < BaseExporter
    attr_accessor :resource_content

    def initialize(base_path:, resource_content:)
      super(base_path: base_path, name: resource_content.sqlite_file_name)
      @resource_content = resource_content
    end

    def export_sqlite
      resource_type = resource_content.meta_value('morphology_resource_type').to_s.downcase
      case resource_type
      when 'lemma'
        export_lemma
      when 'stem'
        export_stem
      when 'root'
        export_root
      when 'morphology'
        export_morphology
      end
    end

    protected
    def export_lemma
      columns = {
        id: 'INTEGER',
        text: 'TEXT',
        text_clean: 'TEXT',
        words_count: 'INTEGER',
        uniq_words_count: 'INTEGER'
      }

      word_columns = {
        lemma_id: 'INTEGER',
        word_location: 'TEXT',
        text: 'TEXT'
      }

      db_file_path = "#{@export_file_path}.db"
      statement = create_sqlite_table(db_file_path, 'lemmas', columns)
      words_statement = create_sqlite_table(db_file_path, 'lemma_words', word_columns)

      Lemma.in_batches(of: 1000) do |batch|
        batch.each do |record|
          fields = [record.id, record.text_madani, record.text_clean, record.words_count, record.uniq_words_count]
          statement.execute(fields)

          record.words.each do |word|
            word_fields = [record.id, word.location, word.text_qpc_hafs]
            words_statement.execute(word_fields)
          end
        end
      end

      db_file_path
    end

    def export_stem
      columns = {
        id: 'INTEGER',
        text: 'TEXT',
        text_clean: 'TEXT',
        words_count: 'INTEGER',
        uniq_words_count: 'INTEGER'
      }

      word_columns = {
        stem_id: 'INTEGER',
        word_location: 'TEXT',
        text: 'TEXT'
      }

      db_file_path = "#{@export_file_path}.db"
      statement = create_sqlite_table(db_file_path, 'stems', columns)
      words_statement = create_sqlite_table(db_file_path, 'stem_words', word_columns)

      Stem.in_batches(of: 1000) do |batch|
        batch.each do |record|
          fields = [record.id, record.text_madani, record.text_clean, record.words_count, record.uniq_words_count]
          statement.execute(fields)

          record.words.each do |word|
            word_fields = [record.id, word.location, word.text_qpc_hafs]
            words_statement.execute(word_fields)
          end
        end
      end

      db_file_path
    end

    def export_root
      columns = {
        id: 'INTEGER',
        arabic_trilateral: 'TEXT',
        english_trilateral: 'TEXT',
        words_count: 'INTEGER',
        uniq_words_count: 'INTEGER'
      }

      word_columns = {
        root_id: 'INTEGER',
        word_location: 'TEXT',
        text: 'TEXT'
      }

      db_file_path = "#{@export_file_path}.db"
      statement = create_sqlite_table(db_file_path, 'roots', columns)
      words_statement = create_sqlite_table(db_file_path, 'root_words', word_columns)

      Root.in_batches(of: 1000) do |batch|
        batch.each do |record|
          fields = [record.id, record.arabic_trilateral, record.english_trilateral, record.words_count, record.uniq_words_count]
          statement.execute(fields)

          record.words.each do |word|
            word_fields = [record.id, word.location, word.text_qpc_hafs]
            words_statement.execute(word_fields)
          end
        end
      end

      db_file_path
    end

    def export_morphology
      todo
    end
  end
end