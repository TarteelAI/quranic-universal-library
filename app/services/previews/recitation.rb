# frozen_string_literal: true

module Previews
  # A recitation: the audio of one surah (`?surah=`) and the text of its ayahs.
  #
  # A surah-by-surah recitation has one file for the surah. Where it has segment data, each ayah
  # carries its start and end time in that file, so the player can show the ayah being recited;
  # without segments the ayahs have no times. An ayah-by-ayah recitation has one file per ayah,
  # played one after the other, so the playing file names the ayah.
  class Recitation
    Preview = Data.define(:granularity, :highlights, :surah, :surahs, :tracks, :ayahs) do
      def serializer = RecitationResource
    end
    # `track` indexes the preview's tracks; `from` and `to` are milliseconds into that track
    # (nil when unknown; `to` nil means the end of the track).
    Ayah = Data.define(:key, :number, :text, :track, :from, :to)

    def initialize(resource, query)
      @content = resource.resource_content
      @query = query
    end

    def call
      @surahs = Previews.surahs
      @surah = Previews.surah(@query, @surahs)
      @verses = Verse.where(chapter_id: @surah.number).order(:verse_number)
                     .pluck(:verse_key, :verse_number, :text_uthmani)
      @content&.one_ayah? ? by_ayah : by_surah
    end

    private

    def by_surah
      recitation = ::Audio::Recitation.find_by(resource_content_id: @content&.id)
      file = recitation && ::Audio::ChapterAudioFile.where(audio_recitation_id: recitation.id,
                                                           chapter_id: @surah.number)
                                                    .where.not(audio_url: [nil, '']).order(:id).first
      return missing unless file

      times = ::Audio::Segment.where(audio_recitation_id: recitation.id, chapter_id: @surah.number)
                              .where.not(timestamp_from: nil)
                              .pluck(:verse_number, :timestamp_from, :timestamp_to)
                              .to_h { |number, from, to| [number, [from, to]] }
      ayahs = @verses.map do |key, number, text|
        from, to = times[number]
        Ayah.new(key:, number:, text:, track: 0, from:, to:)
      end
      preview('surah', highlights: times.any?, tracks: [file.audio_url], ayahs:)
    end

    def by_ayah
      recitation = ::Recitation.find_by(resource_content_id: @content&.id)
      files = recitation ? AudioFile.where(recitation_id: recitation.id, chapter_id: @surah.number).to_a : []
      urls = files.select { |file| file.url.present? || file[:audio_url].present? }
                  .to_h { |file| [file.verse_number, file.audio_url] }
      return missing if urls.empty?

      tracks = []
      ayahs = @verses.map do |key, number, text|
        url = urls[number]
        tracks << url if url
        Ayah.new(key:, number:, text:, track: url && (tracks.size - 1), from: url && 0, to: nil)
      end
      preview('ayah', highlights: true, tracks:, ayahs:)
    end

    def preview(granularity, **)
      Preview.new(granularity:, surah: @surah, surahs: @surahs, **)
    end

    def missing
      Unavailable.new(reason: "This recitation has no audio for Surah #{@surah.name} yet.")
    end
  end
end
