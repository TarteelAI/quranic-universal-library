class TranscriptSplitter
  STT_TRANSCRIPT_PATH = "data/stt"

  def initialize(reciter_id:)
    @reciter_id = reciter_id.to_i
    @base_dir = "#{STT_TRANSCRIPT_PATH}/#{@reciter_id}"
    @transcript_path = "#{@base_dir}/transcript.txt"
  end

  def split
    lines = File.readlines(@transcript_path, chomp: true)

    if lines.size != 114
      raise "Expected 114 lines in #{@transcript_path}, got #{lines.size}"
    end

    output_dir = "#{@base_dir}/by_surah"
    FileUtils.mkdir_p(output_dir)

    lines.each_with_index do |line, index|
      surah_number = index + 1
      File.write("#{output_dir}/#{surah_number}.txt", line)
    end

    puts "Split transcript into 114 files in #{output_dir}"
  end

  def split_states
    json_path = "#{STT_TRANSCRIPT_PATH}/#{@reciter_id}/states.json"
    raw = File.read(json_path)
    data = JSON.parse(raw)

    output_dir = "/Volumes/dev/code/voice-server/data/audio_transcripts/#{@reciter_id}"
    FileUtils.mkdir_p(output_dir)

    data.each do |key, value|
      surah_number = File.basename(key, ".*").to_i
      if surah_number < 1 || surah_number > 114
        puts "Skipping unexpected key: #{key}"
        next
      end

      surah_states = value['data']
      File.write("#{output_dir}/#{surah_number}.json", JSON.pretty_generate(surah_states))
    end

    puts "Split STT states into #{output_dir}"
  end

  def join
    output_dir = "#{@base_dir}/fixed"
    output_path = "#{@base_dir}/fixed/transcript.txt"

    lines = (1..114).map do |surah_number|
      path = "#{output_dir}/by_surah/#{surah_number}.txt"
      raise "Missing transcript file: #{path}" unless File.exist?(path)

      File.read(path).chomp
    end

    File.write(output_path, lines.join("\n") + "\n")
    puts "Joined 114 transcripts into #{output_path}"
  end
end

=begin
[1, 2, 3, 4, 6, 7, 9, 10, 12, 13, 65, 161, 164, 174, 175, 179].each do |reciter_id|
  splitter = TranscriptSplitter.new(reciter_id: reciter_id)
  splitter.split
  splitter.split_states
end
=end
