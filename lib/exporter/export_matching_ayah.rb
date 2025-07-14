module Exporter
  class ExportMatchingAyah < BaseExporter
    attr_accessor :min_match_score

    def initialize(base_path:, min_match_score:)
      super(base_path: base_path, name: 'matching_ayah')
      @min_match_score = min_match_score
    end

    def export_sqlite
      db_file_path = "#{@export_file_path}.db"
      statement = create_sqlite_table(db_file_path, 'similar_ayahs', sqlite_db_columns)

      Verse.find_each do |v|
        matching = v.get_matching_verses
        matching = matching.approved.where("score >= ?", min_match_score)

        if matching.present?

          matching.each do |m|
            next if v.id == m.matched_verse_id

            fields = [
              v.verse_key,
              m.matched_verse.verse_key,
              m.matched_word_positions.count,
              m.coverage.to_i,
              m.score.to_i,
              to_ranges(m.matched_word_positions).to_json.gsub(/\s+/, '')
            ]

            statement.execute(fields)
          end
        end
      end

      close_sqlite_table

      db_file_path
    end

    def export_json
      json_file_path = "#{@export_file_path}.json"
      json_data = {}

      Verse.find_each do |v|
        matching = v.get_matching_verses
        matching = matching.approved.where("score >= ?", min_match_score)

        if matching.present?
          json_data[v.verse_key] = []

          matching.each do |m|
            next if v.id == m.matched_verse_id

            json_data[v.verse_key].push(
              {
                matched_ayah_key: m.matched_verse.verse_key,
                matched_words_count: m.matched_word_positions.count,
                coverage: m.coverage.to_i,
                score: m.score.to_i,
                match_words: to_ranges(m.matched_word_positions)
              }
            )
          end
        end
      end

      write_json(json_file_path, json_data)

      json_file_path
    end

    protected

    def to_ranges(array)
      result = []
      range = []
      last_num = nil
      array = array.uniq.map(&:to_i).sort

      array.each do |num|
        if last_num.nil? || last_num + 1 == num
          range.push(num)
        else
          result.push([range.first, range.last].uniq) if range.present?
          range = [num]
        end

        last_num = num
      end

      result.push([range.first, range.last].uniq) if range.present?

      result
    end

    def sqlite_db_columns
      {
        verse_key: 'TEXT',
        matched_ayah_key: 'TEXT',
        matched_words_count: 'INTEGER',
        coverage: 'INTEGER',
        score: 'INTEGER',
        match_words_range: 'TEXT'
      }
    end
  end
end