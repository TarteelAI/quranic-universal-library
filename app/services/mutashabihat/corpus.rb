module Mutashabihat
  # Every word of the Quran, loaded once and kept in memory, with the forms
  # we compare on. Matching two words goes from strict to loose:
  #
  #   norm     same spelling (diacritics and hamza/alef forms ignored)
  #   bare     same spelling without a leading و or ف
  #   stem_id  same word once prefixes and suffixes are dropped (منها / من)
  #   lemma_id same dictionary word in a different form (يعملون / تعملون)
  #   root_id  same root, a different word (أنزلنا / تنزيل)
  class Corpus
    Token = Struct.new(:verse_id, :position, :text, :norm, :bare, :stem_id, :lemma_id, :root_id, keyword_init: true) do
      # Key used to find candidate ayahs. Lemma is loose enough to survive
      # prefix and form changes, and particles without a lemma fall back to stem.
      def key
        @key ||= lemma_id ? "l#{lemma_id}" : (stem_id ? "s#{stem_id}" : "n#{norm}")
      end
    end

    LOCK = Mutex.new

    class << self
      def instance
        LOCK.synchronize { @instance ||= new.tap(&:load!) }
      end

      def reset!
        LOCK.synchronize { @instance = nil }
      end
    end

    # A lemma found in at most this many ayahs is distinctive enough that
    # sharing it, with particles around it, can make a phrase (أنعمت, 16 ayahs)
    RARE_LEMMA_AYAHS = 30

    attr_reader :verse_keys

    def load!
      @tokens = Hash.new { |h, k| h[k] = [] }
      @verse_keys = Verse.pluck(:id, :verse_key).to_h

      Word
        .where(char_type_name: 'word')
        .order(:verse_id, :position)
        .pluck(:verse_id, :position, :text_imlaei_simple, :stem_id, :lemma_id, :root_id)
        .each do |verse_id, position, text, stem_id, lemma_id, root_id|
          norm = self.class.normalize(text)

          @tokens[verse_id] << Token.new(
            verse_id: verse_id,
            position: position,
            text: text,
            norm: norm,
            bare: self.class.strip_conjunction(norm),
            stem_id: stem_id,
            lemma_id: lemma_id,
            root_id: root_id
          )
        end

      count_lemmas
      build_index
      self
    end

    # A content word whose lemma appears in few ayahs
    def rare?(token)
      token.root_id && token.lemma_id && @lemma_ayahs[token.lemma_id].to_i <= RARE_LEMMA_AYAHS
    end

    def tokens(verse_id)
      @tokens.fetch(verse_id, [])
    end

    def tokens_in_range(verse_id, from, to)
      tokens(verse_id).select { |t| t.position >= from && t.position <= to }
    end

    # Ayahs sharing word pairs with the given tokens, most shared first.
    # Pairs skip one word too, so a phrase with one changed word in the
    # middle still finds its siblings.
    def candidate_verse_ids(tokens, exclude: nil, min_shared: 1, limit: 3000)
      counts = Hash.new(0)

      pair_keys(tokens).uniq.each do |pair|
        weight = pair.start_with?('r') ? 2 : 1
        @index[pair]&.each { |verse_id| counts[verse_id] += weight }
      end

      counts.delete(exclude)
      counts
        .select { |_, shared| shared >= min_shared }
        .sort_by { |verse_id, shared| [-shared, verse_id] }
        .first(limit)
        .map(&:first)
    end

    # Find where a typed phrase occurs. Returns [verse_id, from, to] or nil.
    def locate(text)
      words = text.to_s.split(/\s+/).map { |w| self.class.normalize(w) }.compact_blank
      return if words.empty?

      [:norm, :bare].each do |field|
        target = field == :bare ? words.map { |w| self.class.strip_conjunction(w) } : words

        @tokens.each do |verse_id, list|
          values = list.map(&field)

          (0..(values.size - target.size)).each do |i|
            if values[i, target.size] == target
              return [verse_id, list[i].position, list[i + target.size - 1].position]
            end
          end
        end
      end

      nil
    end

    def self.normalize(text)
      text.to_s
          .remove_diacritics
          .tr('أإآٱ', 'اااا')
          .tr('ى', 'ي')
          .tr('ة', 'ه')
          .delete('ـ')
          .gsub(/[^ء-ي]/, '')
    end

    def self.strip_conjunction(norm)
      norm.length > 2 && norm.start_with?('و', 'ف') ? norm[1..] : norm
    end

    protected

    def build_index
      @index = Hash.new { |h, k| h[k] = [] }

      @tokens.each do |verse_id, list|
        pair_keys(list).uniq.each { |pair| @index[pair] << verse_id }
      end
    end

    def count_lemmas
      @lemma_ayahs = Hash.new(0)

      @tokens.each_value do |list|
        list.filter_map(&:lemma_id).uniq.each { |lemma_id| @lemma_ayahs[lemma_id] += 1 }
      end
    end

    # Word pairs keyed two ways: by lemma, and by spelling without a leading
    # و/ف. Lemma ids aren't always consistent for the same word, so the
    # spelling keys catch what the lemma keys miss. Rare words are keys on
    # their own (worth two pairs), since the words around them may differ:
    # الذين أنعمت عليهم / الذين أنعم الله عليهم
    def pair_keys(list)
      keys = [list.map(&:key), list.map { |t| "b#{t.bare}" }].flat_map do |keys|
        pairs = keys.each_cons(2).map { |a, b| "#{a}|#{b}" }
        skips = keys.each_cons(3).map { |a, _, c| "#{a}|*|#{c}" }

        pairs + skips
      end

      keys + list.select { |t| rare?(t) }.map { |t| "r#{t.lemma_id}" }
    end
  end
end
