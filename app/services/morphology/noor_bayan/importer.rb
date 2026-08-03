module Morphology
  module NoorBayan
    class Importer
      BATCH_SIZE = 5_000
      RESOURCE_NAME = 'NoorBayan Quranic Treebank'.freeze

      EXPECTED = {
        tokens: 139_376,
        sentences: 11_693,
        surface: 128_219,
        implicit_pronoun: 6_673,
        elided: 4_484,
        distinct_words: 77_429
      }.freeze

      DIACRITICS = /[ؐ-ًؚ-ٰٟۖ-ۭ]/

      def initialize(csv_path)
        @csv_path = csv_path
      end

      def import!
        rows = load_rows
        reset_tables
        import_sentences(rows)
        import_tokens(rows)
        resolve_head_tokens
        create_resource_content
        verify!
        report
      end

      private

      def load_rows
        rows = []
        CsvReader.new(@csv_path).each_row { |data| rows << Row.new(data) }
        rows
      end

      def reset_tables
        Morphology::WordToken.connection.execute(
          'TRUNCATE morphology_word_tokens, morphology_sentences RESTART IDENTITY'
        )
      end

      def rows_by_sentence(rows)
        rows.group_by(&:sentence_number)
      end

      def import_sentences(rows)
        sentences = rows_by_sentence(rows).map do |number, sentence_rows|
          build_sentence(number, sentence_rows)
        end

        Morphology::Sentence.import!(sentences, batch_size: BATCH_SIZE)
        @sentence_ids = Morphology::Sentence.pluck(:sentence_number, :id).to_h
      end

      def build_sentence(number, sentence_rows)
        attrs = sentence_rows.map(&:attributes)
        chapters = attrs.map { |a| a[:chapter_number] }.uniq
        raise "Sentence #{number} spans chapters #{chapters.inspect}" if chapters.size > 1

        verse_numbers = attrs.map { |a| a[:verse_number] }.uniq.sort
        unless verse_numbers == (verse_numbers.first..verse_numbers.last).to_a
          raise "Sentence #{number} has non-contiguous verses #{verse_numbers.inspect}"
        end

        surface = attrs.select { |a| a[:token_type] == 'surface' }

        Morphology::Sentence.new(
          sentence_number: number,
          chapter_id: chapters.first,
          first_verse_id: verse_id(chapters.first, verse_numbers.first),
          last_verse_id: verse_id(chapters.first, verse_numbers.last),
          verses_count: verse_numbers.size,
          tokens_count: attrs.size,
          words_count: surface.map { |a| [a[:verse_number], a[:word_number]] }.uniq.size,
          text_uthmani: joined_text(surface, :text_uthmani),
          text_qpc_hafs: joined_text(surface, :text_qpc_hafs)
        )
      end

      def joined_text(surface_attrs, key)
        surface_attrs
          .group_by { |a| [a[:verse_number], a[:word_number]] }
          .values
          .map { |word| word.map { |a| a[key] }.join }
          .join(' ')
      end

      def import_tokens(rows)
        rows.each_slice(BATCH_SIZE) do |batch|
          tokens = batch.map { |row| build_token(row) }
          Morphology::WordToken.import!(tokens, batch_size: BATCH_SIZE)
        end
      end

      def build_token(row)
        attrs = row.attributes
        word_id, morphology_word_id = word_ids.fetch(row.word_location, [nil, nil])

        Morphology::WordToken.new(
          attrs.merge(
            sentence_id: @sentence_ids.fetch(row.sentence_number),
            word_id: word_id,
            morphology_word_id: morphology_word_id,
            root_id: root_ids[row.root_ar&.delete(' ')],
            lemma_id: lemma_id_for(row.lemma_ar)
          )
        )
      end

      def resolve_head_tokens
        Morphology::WordToken.connection.execute(<<~SQL)
          UPDATE morphology_word_tokens t
          SET head_token_id = h.id
          FROM morphology_word_tokens h
          WHERE h.sentence_id = t.sentence_id
            AND h.position_in_sentence = t.ref_token_position
            AND t.ref_token_position IS NOT NULL
            AND h.id != t.id
        SQL
      end

      def create_resource_content
        ResourceContent.where(name: RESOURCE_NAME).first_or_create do |resource|
          resource.meta_data = {
            'source-url' => 'https://github.com/NoorBayan/Quranic',
            'license' => 'MIT'
          }
        end
      end

      def verify!
        counts = Morphology::WordToken.group(:token_type).count
        assert_equal EXPECTED[:tokens], Morphology::WordToken.count, 'total tokens'
        assert_equal EXPECTED[:sentences], Morphology::Sentence.count, 'sentences'
        assert_equal EXPECTED[:surface], counts['surface'], 'surface tokens'
        assert_equal EXPECTED[:implicit_pronoun], counts['implicit_pronoun'], 'implicit pronouns'
        assert_equal EXPECTED[:elided], counts['elided'], 'elided tokens'
        assert_equal 0, Morphology::WordToken.surface.where(word_id: nil).count, 'surface tokens without word'
        assert_equal 0, Morphology::WordToken.surface.where(morphology_word_id: nil).count, 'surface tokens without morphology word'
        assert_equal EXPECTED[:distinct_words], Morphology::WordToken.surface.distinct.count(:word_id), 'distinct words'

        unresolved = Morphology::WordToken
                       .where.not(ref_token_position: nil)
                       .where(head_token_id: nil)
                       .where('ref_token_position != position_in_sentence')
                       .count
        assert_equal 0, unresolved, 'unresolved dependency heads'

        labels = Morphology::WordToken.where.not(rel_label: nil).distinct.pluck(:rel_label)
        unresolvable = labels.reject { |label| I18n.exists?("morphology.edge_relations.#{label}") }
        assert_equal 0, unresolvable.size, "rel labels missing i18n entries: #{unresolvable.inspect}"
      end

      def assert_equal(expected, actual, label)
        return if expected == actual

        raise "Verification failed for #{label}: expected #{expected}, got #{actual}"
      end

      def report
        surface = Morphology::WordToken.surface
        puts "Imported #{Morphology::Sentence.count} sentences, #{Morphology::WordToken.count} tokens"
        puts "Root matched: #{percent(surface.where.not(root_id: nil).count, surface.where.not(root_name: nil).count)} of tokens with a root"
        puts "Lemma matched: #{percent(surface.where.not(lemma_id: nil).count, surface.where.not(lemma_name: nil).count)} of tokens with a lemma"
        puts "Heads resolved: #{Morphology::WordToken.where.not(head_token_id: nil).count}"
      end

      def percent(part, total)
        return '0%' if total.zero?

        "#{(part * 100.0 / total).round(1)}% (#{part}/#{total})"
      end

      def verse_id(chapter_number, verse_number)
        verse_ids.fetch([chapter_number, verse_number])
      end

      def verse_ids
        @verse_ids ||= Verse.pluck(:chapter_id, :verse_number, :id).to_h { |c, v, id| [[c, v], id] }
      end

      def word_ids
        @word_ids ||= begin
          morphology = Morphology::Word.pluck(:location, :id).to_h
          Word.pluck(:location, :id).each_with_object({}) do |(location, id), map|
            map[location] = [id, morphology[location]]
          end
        end
      end

      def root_ids
        @root_ids ||= Root.pluck(:text_clean, :id).to_h { |text, id| [text.to_s.delete(' '), id] }
      end

      def lemma_ids
        @lemma_ids ||= begin
          by_madani = Lemma.pluck(:text_madani, :id).to_h
          by_clean = Lemma.pluck(:text_clean, :id)
                          .group_by(&:first)
                          .select { |_, rows| rows.size == 1 }
                          .transform_values { |rows| rows.first.last }
          by_clean.merge(by_madani)
        end
      end

      def lemma_id_for(lemma_ar)
        return if lemma_ar.nil?

        lemma_ids[lemma_ar] || lemma_ids[lemma_ar.gsub(DIACRITICS, '').tr('ٱآأإ', 'اااا')]
      end
    end
  end
end
