# frozen_string_literal: true

module Utils
  class ImportAyahTimingCue
    # Pending  8, 11
    attr_accessor :qdc_recitation, :recitation, :issues

    def initialize(recitation_id, copy_recitation = false)
      @qdc_recitation = Audio::Recitation.find(recitation_id)
      @issues = []

      if copy_recitation
        @recitation = Audio::Recitation.where(name: "#{qdc_recitation.name}(Cue copy)").first_or_initialize
        @recitation.attributes = qdc_recitation.attributes.except('id', 'name')
        @recitation.save(validate: false)

        Audio::ChapterAudioFile.where(audio_recitation_id: qdc_recitation.id).each do |qdc|
          file = Audio::ChapterAudioFile.where(audio_recitation_id: recitation.id,
                                               chapter_id: qdc.chapter_id).first_or_initialize
          file.attributes = qdc.attributes.except('id', 'audio_recitation_id')
          file.save(validate: false)
        end
      else
        @recitation = @qdc_recitation

        Chapter.find_each do |chapter|
          Audio::ChapterAudioFile.where(audio_recitation_id: @recitation.id, chapter: chapter).first_or_create
        end
      end
    end

    def parse(chapter_id = nil)
      data = process_segments

      if chapter_id
        chapter = Chapter.find(chapter_id)
        parse_segment_for_chapter chapter, data
        update_percentiles_for_chapter(chapter)
      else
        Chapter.order('id ASC').each do |chapter|
          parse_segment_for_chapter chapter, data
          update_percentiles_for_chapter(chapter)
        end
      end

      if issues.present?
        File.open("data/raw_segments/#{@qdc_recitation.id}-issues.json", 'wb') do |f|
          f.puts issues.to_json
        end

        puts "Issues #{issues}"
      end
    end

    protected

    def parse_segment_for_chapter(chapter, data)
      silent_duration = 0
      offset = 0
      silent_at_end_duration = 0

      timing = CSV.read("data/raw_segments/#{qdc_recitation.id}/timing/#{chapter.id}.csv")

      surah_audio_file = Audio::ChapterAudioFile
                           .where(
                             chapter_id: chapter.id,
                             audio_recitation: recitation
                           ).first

      chapter.verses.order('verse_number ASC').each do |verse|
        next unless data[verse.verse_key]
        #seg = Audio::Segment.where(verse_id: verse.id, audio_recitation_id: recitation.id).first
        verse_timing = timing[verse.verse_number]

        offset, silent_duration, silent_at_end_duration = parse_segment_for_verse(
          verse, offset,
          silent_duration,
          silent_at_end_duration,
          data[verse.verse_key],
          surah_audio_file,
          verse_timing
        )
      end
    end

    def parse_segment_for_verse(verse, offset, chapter_silent_duration, silent_at_last_ayah_end, verse_segment, audio_file, existing_timing)
      segments = []
      relative_segments = []
      silent_duration = 0
      silent_at_start = nil

      segment = Audio::Segment.where(
        verse_id: verse.id,
        audio_file_id: audio_file.id,
        audio_recitation_id: recitation.id
      ).first_or_initialize

      seg_offset = if use_cue_timing?
                     offset
                   else
                     existing_timing[1].to_f
                   end

      verse_segment[:segments].each do |seg|
        if seg[:token] == -1
          silent_duration += seg[:duration]
        else
          segments.push([seg[:token] + 1, seg_offset + seg[:start] - silent_duration, seg_offset + seg[:end]])

          relative_segments.push([seg[:token] + 1, seg[:start], seg[:end]])
          silent_at_start = silent_duration if silent_at_start.nil?

          silent_duration = 0
        end
      end

      if segments.blank?
        issues.push({ verse.verse_key => 'NO segments' })
        return offset + verse_segment[:duration].to_f
      end

      # Add 5 ms delay for next ayah
      #segments.last[2] -= 5

      # Check if we've segments for all words
      missing_words = ((1..verse.words_count).to_a - segments.map { |a| a[0] })
      issues.push({ verse.verse_key => missing_words }) if segments.size < verse.words_count || missing_words.present?

      segment.segments = segments
      segment.relative_segments = relative_segments

      if use_cue_timing?
          segment.timestamp_from = verse_segment[:time_start] + offset  + silent_at_start + silent_at_last_ayah_end
          segment.timestamp_to = verse_segment[:time_end] + offset + silent_duration
      else
        segment.timestamp_from = existing_timing[1].to_f
        segment.timestamp_to = existing_timing[2].to_f
      end

      segment.timestamp_median = (segment.timestamp_from + segment.timestamp_to) / 2
      segment.duration = (verse_segment[:duration] / 1000.to_f).round(2)
      segment.duration_ms = verse_segment[:duration]
      segment.audio_file_id = audio_file.id
      segment.verse_number = verse.verse_number
      segment.verse_key = verse.verse_key
      segment.chapter_id = verse.chapter_id

      segment.silent_duration = chapter_silent_duration.to_f + silent_at_start + silent_duration.to_f
      segment.relative_silent_duration = silent_at_start

      segment.save

      # return offset for next ayah. Add 5ms delay
      #[segment.timestamp_to - (5 + silent_duration), segment.silent_duration, silent_duration]
      [segment.timestamp_to, segment.silent_duration, silent_duration]
    end

    def process_segments
      segments_data = {}

      load_segments.each do |line|
        surah, ayah, start, duration, token = line.split(' ').map(&:to_i)
        next if ayah < 1

        segments_data["#{surah}:#{ayah}"] ||= {
          segments: [],
          time_start: 0,
          time_end: 0,
          duration: 0
        }

        segments_data["#{surah}:#{ayah}"][:segments].push({ token: token, start: start, end: start + duration,
                                                            duration: duration })
      end

      fix_ayah_timing(segments_data)
    end

    def fix_ayah_timing(segments_data)
      Verse.find_each do |v|
        verse_segments = segments_data[v.verse_key] || { segments: [] }

        if (segments = verse_segments[:segments]).present?
          start_at = segments[0][:start]
          end_at = segments.last[:end]

          verse_segments[:time_start] = start_at
          verse_segments[:time_end] = end_at
          verse_segments[:duration] = end_at - start_at
        end

        segments_data[v.verse_key] = verse_segments
      end

      segments_data
    end

    def load_segments
      file = File.read("data/raw_segments/#{file_id}.js").strip
      JSON.parse(file)
    end

    def file_id
      CUE_TO_RECITATION_MAPPING.key(qdc_recitation.id)
    end

    def use_cue_timing?
      if USE_CUE_TIMING[qdc_recitation.id].nil?
        false
      else
        USE_CUE_TIMING[qdc_recitation.id]
      end
    end

    def use_silent_timing?
      if USE_SILENT_DURATION[qdc_recitation.id].nil?
        true
      else
        USE_SILENT_DURATION[qdc_recitation.id]
      end
    end

    def update_percentiles_for_chapter(chapter)
      audio_file = Audio::ChapterAudioFile.where(
        audio_recitation_id: recitation.id,
        chapter_id: chapter.id
      ).first

      total_duration = audio_file.duration_ms.to_i

      Verse.where(chapter: chapter).order('verse_index ASC').each do |verse|
        if segment = Audio::Segment.where(verse: verse, audio_recitation_id: recitation.id).first
          percentile = (segment.duration_ms.to_f / total_duration) * 100
          segment.update_column(:percentile, percentile.round(2))
        end
      end

      percentiles = []
      0.upto(100) do |i|
        timestamp = (i.to_f / 100) * total_duration
        file_segments = Audio::Segment.where(chapter_id: chapter.id,
                                             audio_recitation_id: recitation.id).order('verse_number ASC')
        segment = find_closest_segment(file_segments, timestamp)

        percentiles.push segment.verse_key
      end

      audio_file.timing_percentiles = percentiles
      audio_file.save(validate: false)
    end

    def find_closest_segment(segments, time)
      closest_segment = segments[0]
      closest_diff = (closest_segment.timestamp_median - time).abs

      segments.each do |segment|
        diff = (segment.timestamp_median - time).abs

        if closest_diff >= diff && time > closest_segment.timestamp_to
          closest_diff = diff
          closest_segment = segment
        end
      end

      closest_segment
    end

    USE_CUE_TIMING = {
      6 => false
    }.freeze

    USE_SILENT_DURATION = {
      12 => false
    }.freeze

    CUE_TO_RECITATION_MAPPING = {
      # Cue ID => QDC recitation ID
      # Done
      104 => 12, # Mahmoud Khalil Al-Husary	- Muallim
      120 => 7, # Mishari Rashid al-`Afasy
      1 => 9, # Mohamed Siddiq al-Minshawi - Murattal
      # 201 => 10, # Sa`ud ash-Shuraym - NODE: used QDC segments for this and there are some missing segments we need to fix
      131 => 161, # Khalifah Taniji,
      115 => 3, # Abdur-Rahman as-Sudais

      102 => 2, # AbdulBaset - Murattal
      125 => 13, # Saad al-Ghamdi

      # Pending
      112 => 162, # Abdullah Awad al-Juhani
      116 => 4, # Abu Bakr al-Shatri
      126 => 5, # Hani ar-Rifai
      #128 => 6, # Mahmoud Khalil Al-Husary this doesn't have segments for all ayah
      103 => 6, # Mahmoud Khalil Al-Husary, 103
      202 => 8, # Mohamed Siddiq al-Minshawi - Majwad. 135 and 202 same(Update: 135 has no segment)
      101 => 11, # Mohamed al-Tablawi	136 and 101 are same...
      143 => 18, # Salah Bukhatir
      140 => 11, # AbdulMuhsin al-Qasim( TODO: CHANGE ID, 11 is Mohamed al-Tablawi)
      139 => 169, # Muhammad Jibreel
      141 => 104, # Nasser Al Qatami,
      138 => 22, # Muhammad Ayyoob	5 and 138 same?? on could 107 (Taraweeh)
      119 => 127, # Akram Al-Alaqmi
      117 => 19, # Ahmed ibn Ali al-Ajmy
      122 => 158, # Abdullah Ali Jabir
      129 => 103, # Ibrahim Al Akhdar	7 and 129 are same
      113 => 163, # Abdullah Basfar	 113 and 8 are same( one of them could be 66)
      121 => 128, # Ali Hajjaj Alsouasi
      123 => 44, # Aziz Alili,
      127 => 167, # Ali Abdur-Rahman al-Huthaify 9 and 127 are same
      114 => 124, # Abdullah Matroud
      124 => 114, # Fares Abbad
      132 => 116, # Khalid al-Qahtani
      133 => 159, # Maher al-Muaiqly,
      134 => 129, # Mahmood Ali Al-Bana
      137 => 70, # Muhammad Abdul-Kareem
      142 => 17, # Sahl Yasin
      144 => 43 # Salah al-Budair
    }.freeze
  end
end
