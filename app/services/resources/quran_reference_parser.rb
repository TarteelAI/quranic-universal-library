# frozen_string_literal: true

require 'yaml'

module Resources
  class QuranReferenceParser
    AliasEntry = Struct.new(:chapter, :value, :comparison_value, :source, keyword_init: true)
    NamedCandidate = Struct.new(:name, :ayah_number, :matched_text, keyword_init: true)

    ParsedReference = Struct.new(
      :verse,
      :verse_key,
      :chapter,
      :chapter_id,
      :verse_number,
      :matched_text,
      :remaining_query,
      keyword_init: true
    )

    NUMERIC_PATTERNS = [
      /(?<ref>\b(?:surah\s+)?(?<chapter>\d{1,3})\s*:\s*(?<ayah>\d{1,3})\b)/,
      /(?<ref>\b(?:surah\s+)?(?<chapter>\d{1,3})\s+(?:ayah\s+|verse\s+)?(?<ayah>\d{1,3})\b)/
    ].freeze
    NAMED_JOINERS = %w[ayah verse].freeze

    def initialize(query)
      @query = query.to_s
    end

    def parse
      return if normalized_query.blank?

      numeric_match = find_numeric_match
      return build_reference(numeric_match) if numeric_match

      named_match = find_named_match
      build_reference(named_match) if named_match
    end

    private

    attr_reader :query

    def normalized_query
      @normalized_query ||= normalize(query)
    end

    def normalize(text)
      text.to_s
        .unicode_normalize(:nfkc)
        .downcase
        .gsub(/\p{Latin}+/) { |segment| ActiveSupport::Inflector.transliterate(segment) }
        .tr('-', ' ')
        .gsub(/[^\p{Arabic}a-z0-9:\s]/u, ' ')
        .squeeze(' ')
        .strip
    end

    def comparison_normalize(text)
      tokens = normalize(text).split
      tokens.shift if tokens.first == 'al'

      tokens.map do |token|
        token.gsub(/ee+/, 'i')
             .gsub(/ii+/, 'i')
             .gsub(/aa+/, 'a')
             .gsub(/ea/, 'a')
             .gsub(/oo+/, 'u')
             .gsub(/ou/, 'u')
             .gsub(/uu+/, 'u')
             .sub(/h\z/, '')
      end.reject(&:blank?).join(' ')
    end

    def find_numeric_match
      NUMERIC_PATTERNS.each do |pattern|
        if (match = normalized_query.match(pattern))
          return {
            chapter_id: match[:chapter].to_i,
            verse_number: match[:ayah].to_i,
            matched_text: match[:ref]
          }
        end
      end

      nil
    end

    def find_named_match
      named_candidates.each do |candidate|
        chapter = match_named_candidate(candidate.name)
        next unless chapter

        return {
          chapter_id: chapter.chapter_number,
          verse_number: candidate.ayah_number,
          matched_text: candidate.matched_text
        }
      end

      nil
    end

    def named_candidates
      @named_candidates ||= begin
        tokens = tokenized_query
        max_name_tokens = chapter_alias_entries.map { |entry| entry.value.split.size }.max || 1

        tokens.each_with_index.flat_map do |token, index|
          next [] unless token[:text].match?(/\A\d{1,3}\z/)

          ayah_number = token[:text].to_i
          next [] if ayah_number.zero?

          name_end = NAMED_JOINERS.include?(tokens[index - 1]&.dig(:text)) ? index - 2 : index - 1
          next [] if name_end.negative?

          surah_index = tokens[0..name_end].rindex { |entry| entry[:text] == 'surah' }
          name_start_floor = surah_index ? surah_index + 1 : 0
          name_start_ceiling = [name_end - max_name_tokens + 1, name_start_floor].max

          (name_start_ceiling..name_end).to_a.sort_by { |start_index| -(name_end - start_index + 1) }.filter_map do |start_index|
            slice = tokens[start_index..name_end]
            next if slice.blank?

            matched_start = start_index.positive? && tokens[start_index - 1][:text] == 'surah' ? start_index - 1 : start_index

            NamedCandidate.new(
              name: slice.map { |entry| entry[:text] }.join(' '),
              ayah_number: ayah_number,
              matched_text: normalized_query[tokens[matched_start][:start]...tokens[index][:finish]]
            )
          end
        end
      end
    end

    def tokenized_query
      @tokenized_query ||= normalized_query.to_enum(:scan, /\S+/).map do
        match = Regexp.last_match
        { text: match[0], start: match.begin(0), finish: match.end(0) }
      end
    end

    def match_named_candidate(candidate_name)
      candidate = normalize(candidate_name)
      return if candidate.blank?

      exact_canonical = unique_chapter(exact_alias_matches(candidate, source: :canonical))
      return exact_canonical if exact_canonical

      exact_curated = preferred_chapter(exact_alias_matches(candidate, source: :curated))
      return exact_curated if exact_curated

      comparable_candidate = comparison_normalize(candidate)
      return if comparable_candidate.blank?

      normalized_canonical = unique_chapter(normalized_alias_matches(comparable_candidate, source: :canonical))
      return normalized_canonical if normalized_canonical

      normalized_curated = preferred_chapter(normalized_alias_matches(comparable_candidate, source: :curated))
      return normalized_curated if normalized_curated

      fuzzy_alias_match(candidate, comparable_candidate)
    end

    def exact_alias_matches(candidate, source:)
      chapter_alias_entries.select do |entry|
        entry.source == source && entry.value == candidate
      end
    end

    def normalized_alias_matches(comparable_candidate, source:)
      chapter_alias_entries.select do |entry|
        entry.source == source &&
        entry.comparison_value == comparable_candidate
      end
    end

    # Keep fuzzy matching narrow so typo tolerance helps real surah refs without turning plain search into guesswork.
    def fuzzy_alias_match(candidate, comparable_candidate)
      threshold = fuzzy_threshold(candidate.delete(' ').length)
      token_count = candidate.split.size

      matches = chapter_alias_entries.filter_map do |entry|
        next if entry.comparison_value.blank?
        next unless entry.value.split.size == token_count
        next if entry.comparison_value.delete(' ').length < 5
        next if (entry.comparison_value.length - comparable_candidate.length).abs > 1

        distance = levenshtein_distance(entry.comparison_value, comparable_candidate)
        next if distance > threshold

        { chapter: entry.chapter, distance: distance, alias: entry.value }
      end

      return if matches.empty?

      matches.sort_by! { |match| [match[:distance], match[:alias].length, match[:alias]] }
      best = matches.first
      second = matches[1]
      return if second && second[:distance] == best[:distance]

      best[:chapter]
    end

    def unique_chapter(matches)
      chapters = matches.map(&:chapter).uniq { |chapter| chapter.chapter_number }
      chapters.one? ? chapters.first : nil
    end

    def preferred_chapter(matches)
      matches.first&.chapter
    end

    def chapter_alias_entries
      @chapter_alias_entries ||= Chapter
        .select(:chapter_number, :name_simple, :name_complex)
        .sort_by { |chapter| chapter.chapter_number.to_i }
        .flat_map do |chapter|
          canonical_entries_for(chapter) + curated_entries_for(chapter)
        end
    end

    def canonical_entries_for(chapter)
      chapter_name_variants(chapter).map do |variant|
        AliasEntry.new(
          chapter: chapter,
          value: variant,
          comparison_value: comparison_normalize(variant),
          source: :canonical
        )
      end
    end

    def curated_entries_for(chapter)
      alias_names = curated_aliases.fetch(chapter.chapter_number.to_i, [])

      alias_names.filter_map do |alias_name|
        normalized = normalize(alias_name)
        next if normalized.blank?

        AliasEntry.new(
          chapter: chapter,
          value: normalized,
          comparison_value: comparison_normalize(normalized),
          source: :curated
        )
      end
    end

    def chapter_name_variants(chapter)
      [chapter.name_simple, chapter.name_complex].compact.flat_map do |name|
        normalized = normalize(name)
        next [] if normalized.blank?

        variants = [normalized]
        variants << normalized.delete_prefix('al ') if normalized.start_with?('al ')
        variants
      end.compact.reject(&:blank?).uniq
    end

    def curated_aliases
      @curated_aliases ||= begin
        path = File.expand_path('../../../config/resources/surah_name_aliases.yml', __dir__)

        if File.exist?(path)
          raw = YAML.safe_load(File.read(path), permitted_classes: [], aliases: false) || {}
          raw.each_with_object({}) do |(chapter_number, aliases), memo|
            memo[chapter_number.to_i] = Array(aliases)
          end
        else
          {}
        end
      end
    end

    def build_reference(match_data)
      return if match_data.blank?

      verse = Verse.includes(:chapter).find_by(
        chapter_id: match_data[:chapter_id],
        verse_number: match_data[:verse_number]
      )
      chapter = verse&.chapter || Chapter.find_by(chapter_number: match_data[:chapter_id])
      verse_key = verse&.verse_key || "#{match_data[:chapter_id]}:#{match_data[:verse_number]}"

      ParsedReference.new(
        verse: verse,
        verse_key: verse_key,
        chapter: chapter,
        chapter_id: match_data[:chapter_id],
        verse_number: match_data[:verse_number],
        matched_text: match_data[:matched_text],
        remaining_query: strip_reference_text(match_data[:matched_text])
      )
    end

    def strip_reference_text(matched_text)
      normalized_query.sub(matched_text.to_s, '').squeeze(' ').strip
    end

    def fuzzy_threshold(length)
      length <= 5 ? 1 : 2
    end

    def levenshtein_distance(left, right)
      return right.length if left.empty?
      return left.length if right.empty?

      previous_row = (0..right.length).to_a

      left.each_char.with_index(1) do |left_char, left_index|
        current_row = [left_index]

        right.each_char.with_index(1) do |right_char, right_index|
          substitution_cost = left_char == right_char ? 0 : 1

          current_row << [
            current_row[right_index - 1] + 1,
            previous_row[right_index] + 1,
            previous_row[right_index - 1] + substitution_cost
          ].min
        end

        previous_row = current_row
      end

      previous_row.last
    end
  end
end
