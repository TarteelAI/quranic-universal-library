# frozen_string_literal: true

module Audio
  # Data for the gapless ayah extractor tool: every recitation that has audio
  # and segments for a surah, with each ayah's segment.
  #
  # Output file names come from the audio url:
  #   .../quran/surah/abdulBasit/mujawwad/mp3/073.mp3 => abdulBasitmujawwad
  class GaplessAyahExtractor
    # Recitations with this tag are ticked by default, a quick pick of the ones we usually cut.
    DEFAULT_TAG = 'Tarteel recitation'

    def initialize(chapter)
      @chapter = chapter
    end

    def as_json(*)
      {
        surah: @chapter.chapter_number,
        verses: @chapter.verses_count,
        texts: Verse.where(chapter_id: @chapter.id).pluck(:verse_number, :text_digital_khatt).to_h,
        reciters: reciters
      }
    end

    private

    def reciters
      files = Audio::ChapterAudioFile.where(chapter_id: @chapter.id)
                                     .where.not(audio_url: [nil, ''])
                                     .includes(audio_recitation: :recitation_style)
                                     .index_by(&:audio_recitation_id)

      segments = Audio::Segment.where(chapter_id: @chapter.id, audio_file_id: files.values.map(&:id))
                               .pluck(:audio_file_id, :verse_number, :timestamp_from, :timestamp_to)
                               .group_by(&:first)

      default_ids = default_resource_ids

      files.values.filter_map do |file|
        recitation = file.audio_recitation
        ayahs = segments[file.id]
        next if recitation.nil? || ayahs.blank?

        {
          id: recitation.id,
          name: recitation.name.to_s.strip,
          style: recitation.recitation_style&.name,
          default: default_ids.include?(recitation.resource_content_id),
          url: file.audio_url,
          kbps: kbps(file.bit_rate),
          out: output_name(file.audio_url),
          ayahs: ayahs.to_h { |_, verse, from, to| [verse, [from, to]] }
        }
      end.sort_by { |r| [r[:default] ? 0 : 1, r[:name]] }
    end

    def default_resource_ids
      ResourceTag.joins(:tag)
                 .where(resource_type: 'ResourceContent', tags: { name: DEFAULT_TAG })
                 .pluck(:resource_id)
                 .to_set
    end

    # bit_rate is stored as bps on some rows and kbps on others.
    def kbps(rate)
      rate = rate.to_i
      rate = (rate / 1000.0).round if rate > 1000
      rate.positive? ? rate : nil
    end

    def output_name(url)
      path = URI(url).path
      if (m = path.match(%r{/surah/(.+)/mp3/[^/]+\z}))
        m[1].delete('/')
      else
        path.split('/').reject(&:blank?)[0..-2].last(2).join('_').gsub(/[^\w-]/, '')
      end
    end
  end
end
