module Exporter
  class ExportQuranicMorphology < BaseExporter
    attr_accessor :resource_content

    def initialize(base_path:, resource_content:)
      super(base_path: base_path, name: resource_content.sqlite_file_name)
      @resource_content = resource_content
    end

    def export_sqlite
      resource_type = resource_content.meta_value('morphology-resource-type').to_s.downcase

      db_path = case resource_type
                when 'lemma'
                  resource_content.one_word? ? export_word_lemma : export_verse_lemma
                when 'stem'
                  resource_content.one_word? ? export_word_stem : export_verse_stem
                when 'root'
                  resource_content.one_word? ? export_word_root : export_verse_root
                when 'morphology'
                  export_morphology
                end

      close_sqlite_table
      db_path
    end

    protected

    def export_verse_lemma
      columns = {
        verse_key: 'TEXT',
        text: 'TEXT'
      }

      db_file_path = "#{@export_file_path}.db"
      statement = create_sqlite_table(db_file_path, 'lemmas', columns)

      Verse.includes(:verse_lemma).find_each do |verse|
        lemma = verse.verse_lemma
        next if lemma.blank?

        statement.execute(
          [
            verse.verse_key,
            lemma.text_madani
          ]
        )
      end

      close_sqlite_table
      db_file_path
    end

    def export_verse_root
      columns = {
        verse_key: 'TEXT',
        text: 'TEXT'
      }

      db_file_path = "#{@export_file_path}.db"
      statement = create_sqlite_table(db_file_path, 'roots', columns)

      Verse.includes(:verse_root).find_each do |verse|
        root = verse.verse_root
        next if root.blank?

        statement.execute(
          [
            verse.verse_key,
            root.value
          ]
        )
      end

      close_sqlite_table
      db_file_path
    end

    def export_verse_stem
      columns = {
        verse_key: 'TEXT',
        text: 'TEXT'
      }

      db_file_path = "#{@export_file_path}.db"
      statement = create_sqlite_table(db_file_path, 'stems', columns)

      Verse.includes(:verse_stem).find_each do |verse|
        stem = verse.verse_stem
        next if stem.blank?

        statement.execute(
          [
            verse.verse_key,
            stem.text_madani
          ]
        )
      end

      close_sqlite_table
      db_file_path
    end


    def export_word_lemma
      columns = {
        id: 'INTEGER',
        text: 'TEXT',
        text_clean: 'TEXT',
        words_count: 'INTEGER',
        uniq_words_count: 'INTEGER'
      }

      word_columns = {
        lemma_id: 'INTEGER',
        word_location: 'TEXT'
      }

      db_file_path = "#{@export_file_path}.db"
      statement = create_sqlite_table(db_file_path, 'lemmas', columns)
      words_statement = create_sqlite_table(db_file_path, 'lemma_words', word_columns)

      Lemma.in_batches(of: 1000) do |batch|
        batch.each do |record|
          fields = [
            record.id,
            record.text_madani,
            record.text_clean,
            record.words_count,
            record.uniq_words_count
          ]
          statement.execute(fields)

          record.words.each do |word|
            word_fields = [record.id, word.location]
            words_statement.execute(word_fields)
          end
        end
      end

      db_file_path
    end

    def export_word_stem
      columns = {
        id: 'INTEGER',
        text: 'TEXT',
        text_clean: 'TEXT',
        words_count: 'INTEGER',
        uniq_words_count: 'INTEGER'
      }

      word_columns = {
        stem_id: 'INTEGER',
        word_location: 'TEXT'
      }

      db_file_path = "#{@export_file_path}.db"
      statement = create_sqlite_table(db_file_path, 'stems', columns)
      words_statement = create_sqlite_table(db_file_path, 'stem_words', word_columns)

      Stem.in_batches(of: 1000) do |batch|
        batch.each do |record|
          fields = [
            record.id,
            record.text_madani,
            record.text_clean,
            record.words_count,
            record.uniq_words_count
          ]
          statement.execute(fields)

          record.words.each do |word|
            word_fields = [
              record.id,
              word.location
            ]

            words_statement.execute(word_fields)
          end
        end
      end

      db_file_path
    end

    def export_word_root
      columns = {
        id: 'INTEGER',
        arabic_trilateral: 'TEXT',
        english_trilateral: 'TEXT',
        words_count: 'INTEGER',
        uniq_words_count: 'INTEGER'
      }

      word_columns = {
        root_id: 'INTEGER',
        word_location: 'TEXT'
      }

      db_file_path = "#{@export_file_path}.db"
      statement = create_sqlite_table(db_file_path, 'roots', columns)
      words_statement = create_sqlite_table(db_file_path, 'root_words', word_columns)

      Root.in_batches(of: 1000) do |batch|
        batch.each do |record|
          fields = [
            record.id,
            record.arabic_trilateral,
            record.english_trilateral,
            record.words_count,
            record.uniq_words_count
          ]
          statement.execute(fields)

          record.words.each do |word|
            word_fields = [record.id, word.location]
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