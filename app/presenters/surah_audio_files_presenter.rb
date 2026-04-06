class SurahAudioFilesPresenter < ApplicationPresenter
  def audio_files
    files = Audio::ChapterAudioFile
              .where.not(chapter_id: nil)
              .where(audio_recitation_id: recitation_id)

    if params[:filter_chapter].present?
      files = files.where(chapter_id: params[:filter_chapter])
    end

    files = files
              .eager_load(:chapter)
              .select('audio_chapter_audio_files.*, count(audio_segments.*) as total_segments')
              .joins('left OUTER JOIN audio_segments on audio_segments.audio_file_id = audio_chapter_audio_files.id')
              .group('audio_chapter_audio_files.id, chapters.id')

    files.order("#{sort_key} #{sort_order}")
  end

  def recitations
    Audio::Recitation.all.map do |a|
      [a.humanize, a.id]
    end
  end

  def meta_title
    "Surah Audio Segments Editor"
  end

  def meta_description
    "Prepare and refine precise word-by-word timestamp data for any Quran recitation. Use the Surah Audio Segments Editor to highlight playing words in real time, correct machine-generated segments, and contribute improved timings for your chosen recitation."
  end

  def meta_keywords
    'surah audio segments, Quran audio timestamps, word-by-word sync, recitation timestamp editor, Mishari al-Afasy segments, Saud ash-Shuraym timestamps, Quranic audio tool'
  end

  protected
  def sort_key
    sort_by = params[:sort_key].presence || 'chapter_id'

    if ['chapter_id', 'verse_id'].include?(sort_by)
      sort_by
    else
      'chapter_id'
    end
  end

  def recitation_id
    params[:recitation_id] || params[:id] || 7
  end
end
