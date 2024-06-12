# frozen_string_literal: true

module Utils
  # An utility for merging ayah by ayah audio
  class MergeAyahRecitation
    attr_reader :recitation, :base_path, :hydra

    def initialize(recitation_id)
      @recitation = Audio::Recitation.find(recitation_id)
      @base_path = "#{Rails.root}/data/audio/#{recitation.id}"

      FileUtils.mkdir_p "#{base_path}/ayah_audio_files"
      FileUtils.mkdir_p "#{base_path}/timing_files"
      FileUtils.mkdir_p "#{base_path}/result"
      FileUtils.mkdir_p 'data/raw_segments'
    end

    def merge(chapter_id = nil)
      require 'typhoeus'
      @hydra = Typhoeus::Hydra.new

      if chapter_id
        merge_audio_files_for_chapter Chapter.find(chapter_id)
      else
        Chapter.order('ID ASC').each do |chapter|
          merge_audio_files_for_chapter chapter
        end
      end
    end

    protected

    def merge_audio_files_for_chapter(chapter)
      chapter_audio_files_path = "#{base_path}/ayah_audio_files/#{chapter.id}"
      FileUtils.mkdir_p chapter_audio_files_path

      result_path = "#{base_path}/result/#{chapter.id}.mp3"
      # return if File.exist?(result_path)

      download_ayah_files(chapter, chapter_audio_files_path)
      generate_file_list(chapter, chapter_audio_files_path)
      merge_audio_files(chapter)

      puts "#{base_path}/result/#{chapter.id}.mp3"
    end

    def download_ayah_files(chapter, destination)
      Verse.where(chapter: chapter).find_in_batches(batch_size: 10) do |batch|
        requests = []
        batch.each do |verse|
          next if File.exist?(destination_file_name(destination, verse))
          next unless url = audio_url(verse)

          requests.push download_file(url, verse)
        end

        hydra.run

        requests.each do |request|
          key = request.options[:params][:verse_key].to_s.strip
          File.open(destination_file_name(destination, Verse.find_by(verse_key: key)), 'wb') do |file|
            file.write request.response.body
          end
        end
      end
    end

    def destination_file_name(destination, verse)
      path = verse.verse_number #verse.verse_key.split(':').map { |a| a.rjust(3, '0') }.join

      "#{destination}/#{path}.mp3"
    end

    def audio_url(verse)
      paths = {
        # 2 => 'https://everyayah.com/data/Abdul_Basit_Murattal_64kbps/',
        3 => 'https://everyayah.com/data/Abdurrahmaan_As-Sudais_192kbps',
        #4 => 'https://everyayah.com/data/Abu_Bakr_Ash-Shaatree_128kbps/',
        13 => 'https://everyayah.com/data/Ghamadi_40kbps/',
        161 => 'https://everyayah.com/data/khalefa_al_tunaiji_64kbps',
        6 => 'https://everyayah.com/data/Husary_64kbps/',
        8 => 'https://everyayah.com/data/Minshawy_Mujawwad_192kbps/',
        168 => 'https://quran.ksu.edu.sa/ayat/mp3/Minshawy_Teacher_128kbps/'
      }

      if (base = paths[recitation.id]).present?
        path = verse.verse_key.split(':').map { |a| a.rjust(3, '0') }.join

        "#{base}/#{path}.mp3"
      else
        audio_file = AudioFile.where(recitation_id: recitation, verse_id: verse.id).first

        audio_file.audio_url
      end
    end

    def download_file(url, verse)
      puts "Downloading #{url}"
      request = Typhoeus::Request.new(url, params: { verse_key: verse.verse_key })
      hydra.queue(request)

      request
    end

    def generate_file_list(chapter, audio_files_path)
      FileUtils.mkdir_p "data/raw_segments/#{recitation.id}/timing/"
      timing_file = "#{base_path}/timing_files/#{chapter.id}.txt"
      ayah_duration_file = "data/raw_segments/#{recitation.id}/timing/#{chapter.id}.csv"

      File.open(timing_file, 'wb') do |f|
        Verse.where(chapter_id: chapter.id).order('verse_number ASC').each do |verse|
          f.puts "file '#{destination_file_name(audio_files_path, verse)}'"
        end
      end

      total_duration = 0
      total_duration_ms = 0
      last_end_sec = 0
      last_end_ms = 0

      CSV.open(ayah_duration_file, 'wb') do |f|
        f << ['Ayah', 'Start(ms)', 'End(ms)', 'Duration(ms)', 'Start(s)', 'End(s)', 'Duration(s)']

        Verse.where(chapter_id: chapter.id).order('verse_number ASC').each do |verse|
          puts verse.verse_key
          file_path = destination_file_name(audio_files_path, verse)
          result = `ffmpeg -i #{file_path} 2>&1 | egrep "Duration"`
          matched = result.match(/Duration:\s(?<h>(\d+)):(?<m>(\d+)):(?<s>(\d+))(?<ms>(.\d+))?/)
          duration = (matched[:h].to_i * 3600) + (matched[:m].to_i * 60) + matched[:s].to_i  + matched[:ms].to_f

          duration_ms = duration * 1000
          total_duration += duration
          total_duration_ms += duration_ms

          f << [verse.verse_number, last_end_ms, last_end_ms + duration_ms, duration_ms, last_end_sec,
                last_end_sec + duration, duration]

          last_end_sec += duration
          last_end_ms += duration_ms
        end
      end
    end

    def merge_audio_files(chapter)
      timing_file = "#{base_path}/timing_files/#{chapter.id}.txt"
      result_file = "#{base_path}/result/#{chapter.id}.mp3"

      `ffmpeg -f concat -safe 0 -i #{timing_file} -c copy #{result_file}`
    end
  end
end
