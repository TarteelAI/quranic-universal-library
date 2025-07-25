class Segments::Reciter < Base
  def audio_url(surah_number)
    name = prefix_file_name? ? surah_number.to_s.rjust(3, '0') : surah_number
    "#{audio_cdn_path}/#{name}.mp3"
  end
end