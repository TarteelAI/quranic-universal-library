module Morphology
  module NoorBayan
    # Rewrites every surface token's displayed Arabic from our own mushaf text,
    # replacing NoorBayan's `uthmani_token` (which carries no tashkeel at all for
    # chapters 9-58 - see ScriptAligner for why).
    #
    # Runs as the last stage of an import, and standalone from
    # `rake noor_bayan:refresh_script` to repair data that is already loaded.
    #
    # Non-surface tokens (elided "(*)" markers and implicit pronouns) have no
    # mushaf text to borrow, so they keep whatever NoorBayan supplied.
    class ScriptRefresher
      BATCH_SIZE = 2_000

      # Column on morphology_word_tokens => column on words
      SCRIPTS = {
        'text_qpc_hafs' => :text_qpc_hafs,
        'text_digital_khatt' => :text_digital_khatt
      }.freeze

      def initialize(logger: nil)
        @logger = logger
        @stats = Hash.new(0)
      end

      def refresh!
        updates = build_updates
        apply(updates)
        refresh_sentences!
        report
        @stats
      end

      private

      def log(message)
        @logger ? @logger.call(message) : puts(message)
      end

      # => { token_id => { 'text_qpc_hafs' => '...', 'text_digital_khatt' => '...' } }
      def build_updates
        updates = {}

        tokens_by_verse.each do |(chapter, verse), rows|
          segments = rows.map { |r| r[:text_uthmani].to_s }

          SCRIPTS.each do |token_column, word_column|
            verse_text = verse_texts(word_column)[[chapter, verse]]
            next if verse_text.blank?

            sliced = ScriptAligner.new(verse_text).split(segments)
            sliced.each_with_index do |text, i|
              next if text.nil?

              (updates[rows[i][:id]] ||= {})[token_column] = text
            end
          end

          rows.each_with_index do |row, i|
            if updates.dig(row[:id], 'text_qpc_hafs')
              @stats[:aligned] += 1
            else
              @stats[:unaligned] += 1
              log("  could not place #{chapter}:#{verse} token #{row[:id]} (#{segments[i]})")
            end
          end
        end

        updates
      end

      def apply(updates)
        connection = Morphology::WordToken.connection

        updates.each_slice(BATCH_SIZE) do |slice|
          values = slice.map do |id, columns|
            qpc = connection.quote(columns['text_qpc_hafs'])
            dk  = connection.quote(columns['text_digital_khatt'])
            "(#{id.to_i}, #{qpc}, #{dk})"
          end.join(', ')

          connection.execute(<<~SQL)
            UPDATE morphology_word_tokens AS t
            SET text_qpc_hafs = COALESCE(v.qpc, t.text_qpc_hafs),
                text_digital_khatt = COALESCE(v.dk, t.text_digital_khatt)
            FROM (VALUES #{values}) AS v(id, qpc, dk)
            WHERE t.id = v.id
          SQL
        end
      end

      # The sentence banner is rebuilt from tokens at render time, but the stored
      # sentence text is what the listing pages show, so keep it in step.
      def refresh_sentences!
        Morphology::Sentence.find_each(batch_size: 500) do |sentence|
          rows = Morphology::WordToken
                   .where(sentence_id: sentence.id, token_type: :surface)
                   .order(:position_in_sentence)
                   .pluck(:verse_number, :word_number, :text_qpc_hafs, :text_digital_khatt)

          sentence.update_columns(
            text_qpc_hafs: join_words(rows, 2),
            text_digital_khatt: join_words(rows, 3)
          )
        end
      end

      def join_words(rows, index)
        rows.group_by { |r| [r[0], r[1]] }
            .values
            .map { |word| word.map { |r| r[index] }.join }
            .join(' ')
      end

      # Surface tokens for one verse, in reading order.
      def tokens_by_verse
        @tokens_by_verse ||= Morphology::WordToken
                               .where(token_type: :surface)
                               .order(:chapter_number, :verse_number, :word_number, :position_in_word)
                               .pluck(:id, :chapter_number, :verse_number, :text_uthmani)
                               .map { |id, c, v, t| { id: id, chapter: c, verse: v, text_uthmani: t } }
                               .group_by { |r| [r[:chapter], r[:verse]] }
      end

      # Verse text in one script, built from its words. `char_type_name: 'word'`
      # skips the ayah-number glyph, which is a word row but not part of the verse.
      def verse_texts(word_column)
        @verse_texts ||= {}
        @verse_texts[word_column] ||= begin
          map = Hash.new { |h, k| h[k] = [] }
          ::Word.where(char_type_name: 'word')
              .order(:position)
              .pluck(:location, word_column)
              .each do |location, text|
            chapter, verse, _word = location.split(':').map(&:to_i)
            map[[chapter, verse]] << text.to_s
          end
          map.transform_values { |words| words.join(' ') }
        end
      end

      def report
        log("Script refresh: #{@stats[:aligned]} tokens rewritten, #{@stats[:unaligned]} left as-is")
      end
    end
  end
end
