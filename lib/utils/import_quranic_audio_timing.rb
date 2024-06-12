# frozen_string_literal: true

module Utils
  class ImportQuranicAudioTiming
    class TimingFile < ActiveRecord::Base
      self.table_name = 'timings'
      self.primary_key = 'sura'
    end

    attr_reader :recitation

    def initialize(recitation_id, file_name, clone = false)
      qdc_recitation = Audio::Recitation.find(recitation_id)

      if clone
        @recitation = Audio::Recitation.where(name: "#{qdc_recitation.name}(QuranicAudio copy)").first_or_initialize
        @recitation.attributes = qdc_recitation.attributes.except('id', 'name')
        @recitation.save(validate: false)
      
        Audio::ChapterAudioFile.where(audio_recitation_id: qdc_recitation.id).each do |qdc|
          file = Audio::ChapterAudioFile.where(audio_recitation_id: @recitation.id,
                                             chapter_id: qdc.chapter_id).first_or_initialize
          file.attributes = qdc.attributes.except('id', 'audio_recitation_id')
          file.save(validate: false)
        end
      else
        @recitation = qdc_recitation
      end

      TimingFile.establish_connection({ adapter: 'sqlite3', database: "data/timing_files/#{file_name}.db" })
    end

    def import(chapter_id = nil)
      if chapter_id
        import_segments_for_chapter Chapter.find(chapter_id)
      else
        Chapter.order('ID ASC').each do |chapter|
          import_segments_for_chapter chapter
        end
      end
    end

    def offset_segments(chapter_id=nil)

    end

    def import_segments_for_chapter(chapter)
      surah_audio_file = Audio::ChapterAudioFile
                         .where(chapter_id: chapter.id, audio_recitation: recitation).first

      offset = TimingFile.where(sura: chapter.id, ayah: 1).first.time
      chapter.verses.order('verse_number ASC').each do |verse|
        import_segment_for_verse(verse, 0, surah_audio_file, chapter.verses_count == verse.verse_number)
      end
    end

    def import_segment_for_verse(verse, offset, surah_audio_file, is_last_verse)
      puts verse.verse_key
      timing_start = TimingFile.where(sura: verse.chapter_id, ayah: verse.verse_number).first

      if is_last_verse
        timing_end = TimingFile.where(sura: verse.chapter_id, ayah: 999).first
        timing_end ||= TimingFile.where(sura: verse.chapter_id + 1, ayah: 1).first
        timing_end ||= TimingFile.where(sura: verse.chapter_id, ayah: verse.verse_number).first
      else
        timing_end = TimingFile.where(sura: verse.chapter_id, ayah: verse.verse_number + 1).first
      end

      segment = Audio::Segment.where(
        verse_id: verse.id,
        chapter_id: verse.chapter_id,
        audio_file_id: surah_audio_file.id,
        audio_recitation_id: recitation.id
      ).first_or_initialize

      segment.timestamp_from = timing_start.time - offset
      segment.timestamp_to = timing_end&.time.to_f - offset
      segment.timestamp_median = (segment.timestamp_from + segment.timestamp_to) / 2

      segment.verse_number = verse.verse_number
      segment.verse_key = verse.verse_key
      segment.segments = []

      segment.save(validate: false)
    end
  end
end
