# frozen_string_literal: true

require 'open3'
require 'json'

module Audio
  # Measures how long an audio file actually plays.
  #
  # ffprobe's header duration for an mp3 includes the LAME gapless padding
  # (encoder delay + end padding). Browsers and mobile players trim that
  # padding, so `audio.duration` and the `ended` event land 40-80 ms before
  # the header duration we store in audio_chapter_audio_files.duration_ms.
  # A segment that ends past the playable duration can never be reached.
  class PlayableDuration
    Result = Struct.new(
      :header_ms, :gapless_ms, :playable_ms, :size, :bit_rate, :sample_rate, :codec, :error,
      keyword_init: true
    ) do
      def ok?
        error.nil?
      end
    end

    # Reads only the file header (~0.3s per remote file). Accurate to ~10 ms,
    # verified against full decodes.
    def self.probe(url)
      stdout, stderr, status = Open3.capture3(
        'ffprobe', '-v', 'debug', '-print_format', 'json', '-show_format', '-show_streams',
        cache_busted(url)
      )

      unless status.success?
        http = stderr[/Server returned (\d{3}[^\n]*)/, 1]
        return Result.new(error: http ? "HTTP #{http}" : 'ffprobe failed (file missing or unreadable?)')
      end

      data = JSON.parse(stdout)
      format = data['format'] || {}
      stream = (data['streams'] || []).find { |s| s['codec_type'] == 'audio' } || {}
      sample_rate = stream['sample_rate'].to_i

      header_ms = (format['duration'].to_f * 1000).round

      # The mp3 demuxer logs the LAME tag as "pad <encoder delay> <end padding>"
      # in samples. Without a LAME tag nothing is trimmed on playback.
      pad = stderr.match(/\[mp3[^\]]*\] pad (\d+) (\d+)/)
      gapless_ms =
        if pad && sample_rate.positive?
          ((pad[1].to_i + pad[2].to_i) * 1000.0 / sample_rate).round
        else
          0
        end

      Result.new(
        header_ms: header_ms,
        gapless_ms: gapless_ms,
        playable_ms: header_ms - gapless_ms,
        size: format['size'].to_i,
        bit_rate: (stream['bit_rate'] || format['bit_rate']).to_i,
        sample_rate: sample_rate,
        codec: stream['codec_name']
      )
    rescue JSON::ParserError => e
      Result.new(error: "ffprobe output unreadable: #{e.message}")
    end

    # Full decode. Exact reference, slow. Decodes the local copy when one is
    # present in the cache (data/audio/<recitation_id>/mp3/<chapter>.mp3, the
    # same layout Audio::SplitGaplessAudio uses), otherwise downloads it there
    # first so the next run reuses it. `expected_size` (bytes, from `probe`)
    # guards against reusing a stale copy after the CDN file was replaced.
    def self.decode(url, recitation_id: nil, chapter_id: nil, expected_size: nil)
      source = url
      if recitation_id && chapter_id
        local = cached_file(url, recitation_id: recitation_id, chapter_id: chapter_id, expected_size: expected_size)
        source = local if local
      end

      _out, err, status = Open3.capture3(
        'ffmpeg', '-nostdin', '-hide_banner', '-i', source == url ? cache_busted(url) : source, '-f', 'null', '-'
      )
      return nil unless status.success?

      times = err.scan(/time=(\d+):(\d{2}):(\d{2})\.(\d+)/)
      return nil if times.empty?

      h, m, s, frac = times.last
      ((h.to_i * 3600 + m.to_i * 60 + s.to_i) * 1000) + frac.ljust(3, '0')[0, 3].to_i
    rescue StandardError
      nil
    end

    def self.cache_dir
      ENV['AUDIO_CACHE_DIR'].presence || 'data/audio'
    end

    def self.local_path(url, recitation_id:, chapter_id:)
      ext = File.extname(URI(url).path).presence || '.mp3'
      File.join(cache_dir, recitation_id.to_s, ext.delete('.'), "#{chapter_id.to_s.rjust(3, '0')}#{ext}")
    end

    # Returns the path of a usable local copy, downloading it when missing or
    # when its size does not match `expected_size`. nil when download fails.
    def self.cached_file(url, recitation_id:, chapter_id:, expected_size: nil)
      path = local_path(url, recitation_id: recitation_id, chapter_id: chapter_id)

      if File.exist?(path) && File.size(path).positive?
        return path if expected_size.nil? || expected_size.to_i.zero? || File.size(path) == expected_size.to_i

        puts "  stale local copy #{path} (#{File.size(path)} bytes, CDN has #{expected_size}), re-downloading"
      end

      FileUtils.mkdir_p(File.dirname(path))
      tmp = "#{path}.part"
      ok = system('curl', '-sfL', '--retry', '3', '-o', tmp, cache_busted(url))
      if ok && File.exist?(tmp) && File.size(tmp).positive?
        FileUtils.mv(tmp, path)
        path
      else
        FileUtils.rm_f(tmp)
        nil
      end
    end

    # Runs `work` for each item on `threads` workers, printing progress.
    def self.each_parallel(items, threads: 8, label: 'probed')
      queue = Queue.new
      items.each { |item| queue << item }
      progress = 0
      mutex = Mutex.new

      workers = threads.times.map do
        Thread.new do
          loop do
            item = begin
              queue.pop(true)
            rescue ThreadError
              break
            end

            yield item

            mutex.synchronize do
              progress += 1
              puts "  #{label} #{progress}/#{items.size}" if (progress % 100).zero? || progress == items.size
            end
          end
        end
      end
      workers.each(&:join)
    end

    def self.cache_busted(url)
      "#{url}#{url.include?('?') ? '&' : '?'}#{Time.now.to_i}"
    end
  end
end
