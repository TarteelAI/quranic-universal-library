json.segments do
  @audio_files.each do |file|
    segments = (file&.segments || []).map do |s|
      s.length == 3 ? s : [s[1], s[2], s[3]]
    end

    json.set! file.verse.verse_key do
      json.verse_id file.verse.id
      json.audioUrl file.audio_url
      json.segments segments
      json.set! :words, file.verse.words.map(&:text_qpc_hafs)
    end
  end
end