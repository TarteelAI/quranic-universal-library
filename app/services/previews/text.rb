# frozen_string_literal: true

module Previews
  # A translation, tafsir or transliteration: its text for a range of ayahs of one surah
  # (`?surah=`, `?from=`, `?to=`), with the Arabic of each ayah.
  #
  # An ayah-by-ayah resource has one entry per ayah (translations with their footnotes); a
  # word-by-word one has one entry per ayah holding its words. A tafsir entry covers its group
  # of ayahs, so a tafsir range shows fewer ayahs, and a very long entry is cut to its start
  # (Previews.excerpt). Editor HTML is sanitized here (Previews.sanitize).
  class Text
    RANGE = 10
    MAX_RANGE = 20
    TAFSIR_RANGE = 3
    TAFSIR_MAX_RANGE = 5

    AYAH_MODELS = { 'translation' => Translation, 'transliteration' => Transliteration }.freeze
    WORD_MODELS = { 'translation' => WordTranslation, 'transliteration' => WordTransliteration }.freeze

    Preview = Data.define(:granularity, :locale, :surah, :surahs, :from, :to, :entries) do
      def serializer = TextResource
    end
    Entry = Data.define(:key, :ayahs, :text, :truncated, :footnotes, :words)
    AyahText = Data.define(:key, :text)
    Footnote = Data.define(:id, :text)
    WordText = Data.define(:id, :arabic, :text)

    def initialize(resource, query)
      @type = resource.resource_type
      @content = resource.resource_content
      @query = query
    end

    def call
      surahs = Previews.surahs
      surah = Previews.surah(@query, surahs)
      size, max = tafsir? ? [TAFSIR_RANGE, TAFSIR_MAX_RANGE] : [RANGE, MAX_RANGE]
      from, to = Previews.range(@query, surah.verses_count, size:, max:)
      verses = Verse.where(chapter_id: surah.number, verse_number: from..to).order(:verse_number)
                    .select(:id, :verse_key, :verse_number, :chapter_id, :text_uthmani).to_a

      if tafsir?
        entries, last = tafsirs(verses)
        # A tafsir group can run past the range; the next range starts after it.
        to = [to, last].compact.max
      else
        entries = @content&.one_word? ? words(verses) : ayahs(verses)
      end

      Preview.new(granularity: @content&.one_word? ? 'word' : 'ayah', locale: Previews.locale(@content, 'und'),
                  surah:, surahs:, from:, to:, entries:)
    end

    private

    def tafsir?
      @type == 'tafsir'
    end

    def ayahs(verses)
      rows = AYAH_MODELS.fetch(@type).where(resource_content_id: @content&.id, verse_id: verses.map(&:id))
                        .index_by(&:verse_id)
      footnotes = @type == 'translation' ? footnotes(rows.values.map(&:id)) : {}
      verses.map do |verse|
        row = rows[verse.id]
        entry(verse.verse_key, [verse], text: row && Previews.sanitize(row.text),
                                        footnotes: footnotes.fetch(row&.id, []))
      end
    end

    def footnotes(translation_ids)
      FootNote.where(translation_id: translation_ids).order(:id).pluck(:translation_id, :id, :text)
              .group_by(&:first)
              .transform_values { |notes| notes.map { |_, id, text| Footnote.new(id:, text: Previews.sanitize(text)) } }
    end

    def words(verses)
      words = ::Word.where(verse_id: verses.map(&:id)).reorder(:verse_id, :position)
                    .pluck(:id, :verse_id, :text_uthmani).group_by(&:second)
      texts = WORD_MODELS.fetch(@type).where(resource_content_id: @content&.id)
                         .where(word_id: words.values.flatten(1).map(&:first)).pluck(:word_id, :text).to_h
      verses.map do |verse|
        translated = words.fetch(verse.id, []).select { |id, _, _| texts[id] }
        entry(verse.verse_key, [verse], words: translated.map do |id, _, arabic|
          WordText.new(id:, arabic:, text: Previews.plain(texts[id]))
        end)
      end
    end

    # The tafsir entries that cover any ayah of the range, each with the ayahs of its group, and
    # the number of the last ayah of the surah they cover.
    def tafsirs(verses)
      rows = Tafsir.where(archived: false, resource_content_id: @content&.id)
                   .where('start_verse_id <= ? AND end_verse_id >= ?', verses.last.id, verses.first.id)
                   .order(:start_verse_id).to_a
      return [[], nil] if rows.empty?

      group = Verse.where(id: rows.map(&:start_verse_id).min..rows.map(&:end_verse_id).max)
                   .select(:id, :verse_key, :verse_number, :chapter_id, :text_uthmani).index_by(&:id)
      last = rows.map { |row| group[row.end_verse_id] }
                 .select { |verse| verse&.chapter_id == verses.first.chapter_id }.map(&:verse_number).max
      entries = rows.map do |row|
        ayahs = (row.start_verse_id..row.end_verse_id).filter_map { |id| group[id] }
        text, truncated = Previews.excerpt(Previews.sanitize(row.text))
        key = ayahs.empty? ? row.verse_key : ayahs.values_at(0, -1).map(&:verse_key).uniq.join('–')
        entry(key, ayahs, text:, truncated:)
      end
      [entries, last]
    end

    def entry(key, verses, text: nil, truncated: false, footnotes: [], words: [])
      Entry.new(key:, ayahs: verses.map { |verse| AyahText.new(key: verse.verse_key, text: verse.text_uthmani) },
                text:, truncated:, footnotes:, words:)
    end
  end
end
