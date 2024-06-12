namespace :audio do
  task split_gapeless_segments: :environment do
    recitation_id = 172
    base_path = "segments-data/hadi-toure/optimized/hadi_toure/mp3"

    segments = []
    issues = []

    Chapter.order('id asc').each do |c|
      chapter_segments = []

      Audio::Segment.where(chapter_id: c.id, audio_recitation: recitation_id).order('verse_number ASC').each do |seg|
        ayah_segments = []
        ayay_start = seg.timestamp_from

        seg.segments.each_with_index do |segment, i|
          if seg.verse_number == 1
            s = segment[1]
            e = segment[2]
          else
            seg_start = segment[1]
            s = seg_start - ayay_start

            seg_end = segment[2]
            e = seg_end - ayay_start
          end

          ayah_segments << [s, e]
          issues.push("#{c.id}-#{seg.verse.verse_number}-#{i + 1}") if s < 0 || e <= 0 || s > e
        end

        chapter_segments << ayah_segments
      end

      segments << chapter_segments
    end
  end

  task split_gapeless_audio: :environment do
    def split_ayah(from, to, input, output)
      `ffmpeg -i #{input} -ss #{from} -to #{to} -c copy #{output}`
    end

    recitation_id = 172
    base_path = "segments-data/hadi-toure/optimized/hadi_toure/mp3"

    Chapter.order('id asc').each do |c|
      chapter_path = "#{base_path}/ayah-by-ayah/#{c.id}"
      input = "#{base_path}/#{c.id}.mp3"
      FileUtils.mkdir_p chapter_path

      Audio::Segment.where(chapter_id: c.id, audio_recitation: recitation_id).order('verse_number ASC').each do |seg|
        from = seg.timestamp_from / 1000.0
        to = seg.timestamp_to / 1000.0
        output_file = "#{chapter_path}/#{seg.verse_number}.mp3"

        split_ayah from, to, input, output_file
      end
    end
  end

  task optimize_audio: :environment do
    base_path = "segments-data/hadi-toure"

    def normalize_volume(file, output_path)
      output = `ffmpeg -i '#{file}' -af "volumedetect" -f null /dev/null 2>&1`
      raise "Error getting audio volume from #{file} (#{$?})" unless $?.success?
      max_volume = output.scan(/max_volume: ([\-\d\.]+) dB/).flatten.first
      mean_volume = output.scan(/mean_volume: ([\-\d\.]+) dB/).flatten.first
      return if !max_volume || !mean_volume

      target_volume = -11.8
      output_file = "/tmp/#{File.basename(file)}"
      result = system(*['ffmpeg', '-i', file, '-af', "loudnorm=I=#{target_volume}:TP=-1.5:LRA=11dB", '-c:v', 'copy', output_file])

      raise "Error normalizing audio volume of #{file}" unless result
      FileUtils.mv(output_file, output_path)
    end

    FileUtils.mkdir_p("#{base_path}/optimized/mp3")
    FileUtils.mkdir_p("#{base_path}/optimized/opus")
    FileUtils.mkdir_p("#{base_path}/fixed_volume")

    Dir['/tmp/*.mp3'].each do |f|
      FileUtils.rm f
    end

    Dir["#{base_path}/*.mp3"].each do |input|
      surah = input[/\d+/].to_i
      fixed_volume = "#{base_path}/fixed_volume/#{surah}.mp3"
      mp3 = "#{base_path}/optimized/mp3/#{surah}"
      opus = "#{base_path}/optimized/opus/#{surah}"

      normalize_volume(input, fixed_volume)

      #96 kbps is recommended when streaming is important.
      # https://scribbleghost.net/2022/12/29/convert-audio-to-opus-with-ffmpeg/
      #ffmpeg -i input.mp3 -c:a libmp3lame -b:a 192k output.mp3

      `ffmpeg -y -i #{fixed_volume} -map 0:a:0 -b:a 96k #{mp3}.mp3`

      # Opus version
      `ffmpeg -i #{mp3}.mp3 -c:a libopus -b:a 96k #{opus}.opus`
    end

    Dir['/tmp/*.mp3'].each do |f|
      FileUtils.rm f
    end
  end
end