segments = @audio_file.audio_segments.inject({}) do |mapping, segment|
  mapping[segment.verse_key] = segment
  mapping
end

json.segments do
  @verses.each do |verse|
    key = verse.respond_to?(:ayah_key) ? verse.ayah_key : verse.verse_key # a numbered ayah for a non-Kufi recitation (P7.3)
    segment = segments[key]

    json.set! key do
      json.verse_id verse.respond_to?(:ayah_key) ? verse.kufi_first_verse_id : verse.id
      json.timestamp_from segment&.timestamp_from
      json.timestamp_to segment&.timestamp_to
      json.segments segment&.segments || []
      json.set! :words, verse.words.map(&:text_digital_khatt)
    end
  end
end

json.fileUrl @audio_file.audio_url
