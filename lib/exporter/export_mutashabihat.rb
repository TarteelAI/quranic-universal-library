module Exporter
  class ExportMutashabihat < BaseExporter
    attr_accessor :min_phrase_length, :exported_phrase_ids


    def initialize(base_path:, min_phrase_length: 3)
      super(base_path: base_path, name: 'mutashabihat')
      @min_phrase_length = min_phrase_length
      @exported_phrase_ids = []
    end

    def export_json
      FileUtils.mkdir_p(@export_file_path)
      phrases_json_file_path = "#{@export_file_path}/phrases.json"
      verses_json_file_path = "#{@export_file_path}/phrase_verses.json"

      export_phrases_json(phrases_json_file_path)
      export_phrase_verses_json(verses_json_file_path)

      @export_file_path
    end

    def export_sqlite

    end

    protected

    def export_phrases_json(exported_file_path)
      mapping = {}
      approved = load_phrases

      approved.find_each do |phrase|
        next if mapping[phrase.id] || should_export_phrase?(phrase, approved) == false
        @exported_phrase_ids.push(phrase.id)

        mapping[phrase.id] = {
          surahs: phrase.chapters_count,
          ayahs: phrase.verses_count,
          count: phrase.occurrence,
          source: {
            key: phrase.source_verse.verse_key,
            from: phrase.word_position_from,
            to: phrase.word_position_to
          },
          ayah: {}
        }

        ranges = {}
        phrase.phrase_verses.approved.map do |p_verse|
          ranges[p_verse.verse.verse_key] ||= []
          ranges[p_verse.verse.verse_key].push([p_verse.word_position_from, p_verse.word_position_to])
        end

        mapping[phrase.id][:ayah] = ranges
      end

      write_json(exported_file_path, mapping)
    end

    def export_phrase_verses_json(exported_file_path)
      mapping = {}

      load_phrase_verses.find_each do |p_verse|
        mapping[p_verse.verse.verse_key] ||= []

        if !mapping[p_verse.verse.verse_key].include?(p_verse.phrase_id)
          mapping[p_verse.verse.verse_key].push(p_verse.phrase_id)
        end
      end

      write_json(exported_file_path, mapping)
    end

    def should_export_phrase?(phrase, all_phrases)
      return false if phrase.verses_count < 2 || phrase.occurrence < 2

      parent = all_phrases.where("id != ?", phrase.id).where("text_qpc_hafs_simple like ?", "%#{phrase.text_qpc_hafs_simple}%").first

      if parent
        return false if parent.verses_count == phrase.verses_count && parent.occurrence == phrase.occurrence
        return false if parent.verses_count > phrase.verses_count && parent.text_qpc_hafs_simple.include?(phrase.text_qpc_hafs_simple)
      end

      true
    end

    def load_phrases
      Morphology::Phrase.approved
                        .includes(:source_verse, phrase_verses: :verse)
                        .where('words_count >= ?', min_phrase_length)
                        .where('occurrence > 1')
                        .where('verses_count > 1')
                        .where(review_status: 'new') # TODO: fix the data, review_status should be 'approved' now
    end

    def load_phrase_verses
      Morphology::PhraseVerse
        .approved
        .where(phrase_id: @exported_phrase_ids)
        .includes(:verse)
    end
  end
end