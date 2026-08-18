segments = @audio_file.audio_segments.inject({}) do |mapping, segment|
  mapping[segment.verse_key] = segment
  mapping
end

json.segments do
  @verses.each do |verse|
    segment = segments[verse.verse_key]

    json.set! verse.verse_key do
      json.verse_id verse.id
      json.timestamp_from segment&.timestamp_from
      json.timestamp_to segment&.timestamp_to
      json.segments segment&.segments || []
      json.set! :words, verse.words.map(&:text_qpc_hafs)
    end
  end
end

json.fileUrl @audio_file.audio_url
