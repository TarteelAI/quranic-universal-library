# frozen_string_literal: true

module Previews
  # Surah info, ayah themes, ayah topics, similar ayahs, mutashabihat, morphology and Quran
  # metadata: a small sample (at most LIMIT) of the records the resource's download holds,
  # read the way its exporter (lib/exporter) reads them. Most of these resources export a whole
  # table rather than rows of their own, so the sample is the start of that table, or of the
  # chosen surah (`?surah=`) for the types that go surah by surah. A resource whose records
  # cannot be told (a morphology or metadata kind the exporter does not know) is Unavailable.
  class Records
    LIMIT = 10
    SURAH_TYPES = %w[surah-info ayah-theme similar-ayah mutashabihat morphology].freeze
    # The exporter's thresholds (Exporter::DownloadableResources, Exporter::ExportMutashabihat).
    MIN_MATCH_SCORE = 50
    MIN_PHRASE_WORDS = 3
    # Quran metadata records by the resource's cardinality: the model and its number column.
    DIVISIONS = {
      '1_juz' => [Juz, :juz_number, 'Juz'], '1_hizb' => [Hizb, :hizb_number, 'Hizb'],
      '1_rub' => [RubElHizb, :rub_el_hizb_number, 'Rub el hizb'], '1_manzil' => [Manzil, :manzil_number, 'Manzil'],
      '1_ruku' => [Ruku, :ruku_number, 'Ruku']
    }.freeze

    Preview = Data.define(:limit, :surah, :surahs, :locale, :records) do
      def serializer = RecordsResource
    end
    # `arabic` is Arabic text; `text` plain text and `html` sanitized HTML, in the preview's
    # locale; `tags` short values shown beside the record.
    Record = Data.define(:key, :label, :arabic, :text, :html, :truncated, :tags)

    def initialize(resource, query)
      @type = resource.resource_type
      @content = resource.resource_content
      @query = query
    end

    def call
      surahs = surah_scoped? ? Previews.surahs : []
      @surah = Previews.surah(@query, surahs) if surahs.any?
      records = self.records
      return Unavailable.new(reason: "There is no sample of this #{@type.tr('-', ' ')} resource yet.") unless records

      Preview.new(limit: LIMIT, surah: @surah, surahs:, locale: Previews.locale(@content, 'en'),
                  records: records.first(LIMIT))
    end

    private

    # Records that go surah by surah: the sample is the chosen surah's.
    def surah_scoped?
      SURAH_TYPES.include?(@type) || (@type == 'quran-metadata' && @content&.cardinality_type == '1_ayah')
    end

    def records
      case @type
      when 'surah-info' then surah_info
      when 'ayah-theme' then ayah_themes
      when 'ayah-topics' then topics
      when 'similar-ayah' then similar_ayahs
      when 'mutashabihat' then phrases
      when 'morphology' then morphology
      when 'quran-metadata' then metadata
      end
    end

    def record(key, label, arabic: nil, text: nil, html: nil, tags: [])
      html, truncated = Previews.excerpt(Previews.sanitize(html)) if html
      Record.new(key: key.to_s, label:, arabic:, text:, html:, truncated: truncated || false, tags:)
    end

    def surah_verses
      Verse.where(chapter_id: @surah.number).order(:verse_number)
    end

    def verse_keys(ids)
      Verse.where(id: ids.uniq).pluck(:id, :verse_key).to_h
    end

    def surah_info
      ChapterInfo.where(resource_content_id: @content&.id, chapter_id: @surah.number).limit(LIMIT).map do |info|
        record(info.id, "Surah #{@surah.name}", text: Previews.plain(info.short_text).presence, html: info.text)
      end
    end

    def ayah_themes
      AyahTheme.where(chapter_id: @surah.number).order(:verse_number_from).limit(LIMIT).map do |theme|
        range = [theme.verse_key_from, theme.verse_key_to].uniq.join('–')
        record(theme.id, range, text: theme.theme, tags: Array(theme.keywords))
      end
    end

    def topics
      topics = Topic.order(:id).limit(LIMIT).to_a
      keys = VerseTopic.joins(:verse).where(topic_id: topics.map(&:id)).order('verses.verse_index')
                       .pluck(:topic_id, 'verses.verse_key').group_by(&:first)
      topics.map do |topic|
        ayahs = keys.fetch(topic.id, []).map(&:second)
        tags = ayahs.first(5) + (ayahs.size > 5 ? ["#{ayahs.size - 5} more ayahs"] : [])
        record(topic.id, topic.name, arabic: topic.arabic_name.presence, html: topic.description.presence, tags:)
      end
    end

    def similar_ayahs
      matches = Morphology::MatchingVerse.approved.where(chapter_id: @surah.number)
                                         .where('score >= ?', MIN_MATCH_SCORE)
                                         .order(:verse_id, score: :desc, id: :asc).limit(LIMIT).to_a
      keys = verse_keys(matches.flat_map { |match| [match.verse_id, match.matched_verse_id] })
      matches.map do |match|
        record(match.id, "#{keys[match.verse_id]} and #{keys[match.matched_verse_id]}",
               text: "#{match.matched_words_count} matching words, #{match.coverage}% coverage, score #{match.score}")
      end
    end

    def phrases
      phrases = Morphology::Phrase.approved.where(source_verse_id: surah_verses.pluck(:id))
                                  .where('words_count >= ? AND occurrence > 1 AND verses_count > 1', MIN_PHRASE_WORDS)
                                  .where(review_status: 'new')
                                  .order(:source_verse_id, :word_position_from, :id).limit(LIMIT).to_a
      keys = verse_keys(phrases.map(&:source_verse_id))
      phrases.map do |phrase|
        text = "Repeats #{phrase.occurrence} times in #{phrase.verses_count} ayahs of #{phrase.chapters_count} surahs"
        record(phrase.id, keys[phrase.source_verse_id], arabic: phrase.text_qpc_hafs, text:)
      end
    end

    def morphology
      kind = @content&.meta_value('morphology-resource-type').to_s.downcase
      return unless %w[lemma stem root].include?(kind)

      @content.one_word? ? word_morphology(kind) : ayah_morphology(kind)
    end

    def word_morphology(kind)
      words = ::Word.where(verse_id: surah_verses.select(:id), char_type_name: 'word').reorder(:verse_id, :position)
                    .includes(kind.to_sym).limit(LIMIT)
      words.map do |word|
        value = word.public_send(kind)
        tag = kind == 'root' ? value&.arabic_trilateral : value&.text_madani
        record(word.id, word.location, arabic: word.text_uthmani, tags: [tag].compact)
      end
    end

    def ayah_morphology(kind)
      surah_verses.includes(:"verse_#{kind}").limit(LIMIT).map do |verse|
        value = verse.public_send(:"verse_#{kind}")
        record(verse.id, verse.verse_key, arabic: kind == 'root' ? value&.value : value&.text_madani)
      end
    end

    def metadata
      cardinality = @content&.cardinality_type
      case cardinality
      when '1_chapter' then surahs_metadata
      when '1_ayah' then ayahs_metadata
      when '1_sajda' then sajdas
      else divisions(*DIVISIONS[cardinality]) if DIVISIONS.key?(cardinality)
      end
    end

    def surahs_metadata
      Chapter.order(:id).limit(LIMIT).map do |chapter|
        text = "#{chapter.verses_count} ayahs, revealed in #{chapter.revelation_place}"
        record(chapter.id, "#{chapter.id}. #{chapter.name_simple}", arabic: chapter.name_arabic, text:)
      end
    end

    def ayahs_metadata
      surah_verses.limit(LIMIT).map do |verse|
        record(verse.id, verse.verse_key, text: "Juz #{verse.juz_number}, hizb #{verse.hizb_number}, " \
                                                "page #{verse.page_number}")
      end
    end

    def sajdas
      Verse.unscoped.where.not(sajdah_number: nil).order(:sajdah_number).limit(LIMIT).map do |verse|
        record(verse.id, "Sajdah #{verse.sajdah_number}", text: [verse.verse_key, verse.sajdah_type].compact.join(', '))
      end
    end

    def divisions(model, number_column, label)
      rows = model.order(number_column).limit(LIMIT).to_a
      keys = verse_keys(rows.flat_map { |row| [row.first_verse_id, row.last_verse_id] })
      rows.map do |row|
        record(row.id, "#{label} #{row[number_column]}",
               text: "#{keys[row.first_verse_id]} to #{keys[row.last_verse_id]}, #{row.verses_count} ayahs")
      end
    end
  end
end
