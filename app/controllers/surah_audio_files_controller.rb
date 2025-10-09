class SurahAudioFilesController < CommunityController
  before_action :authenticate_user!, only: [:save_segments]
  before_action :authorize_access!, only: [:save_segments]
  before_action :init_presenter
  def builder_help
    render layout: false
  end

  def index
    files = Audio::ChapterAudioFile
              .where.not(chapter_id: nil)
              .where(audio_recitation: @recitation)

    if params[:filter_chapter].present?
      files = files.where(chapter_id: params[:filter_chapter])
    end

    files = files.eager_load(:chapter)
                 .select('audio_chapter_audio_files.*, count(audio_segments.*) as total_segments')
                 .joins('left OUTER JOIN audio_segments on audio_segments.audio_file_id = audio_chapter_audio_files.id')
                 .group('audio_chapter_audio_files.id, chapters.id')

    @audio_files = files.order("#{sort_key} #{sort_order}")
  end

  def show
    audio_files = Audio::ChapterAudioFile
                    .includes(:chapter, audio_segments: {verse: :words})
                    .where(
                      {
                        audio_recitation: @recitation.id,
                        chapter_id: chapter_id
                      }.compact_blank
                    )


    @audio_file = audio_files.order("audio_segments.#{sort_key} #{sort_order}").first
  end

  def segment_builder
    @audio_file = load_audio_file
  end

  def segments
    @audio_file = load_audio_file

    @verses = Verse.includes(:words)
                   .where(chapter_id: @audio_file.chapter_id)
                   .order('verses.id ASC')
  end

  def save_segments
    audio_file = load_audio_file
    key = params[:verse_key].to_s.strip
    segment = audio_file.audio_segments.where(
      audio_recitation: @recitation,
      verse_key: key
    ).first_or_initialize

    unless @recitation.segment_locked?
      if segment.new_record?
        segment.verse = Verse.find_by(verse_key: key)
        segment.save
      end

      if params['segments'].present?
        segment.set_segments!(params['segments'], current_user)
      else
        segment.update_time_and_offset_segments(
          params[:from],
          params[:to],
          key
        )
      end
    end

    render json: {
      segments: {
        params[:verse_key] => {
          timestamp_from: segment.timestamp_from,
          timestamp_to: segment.timestamp_to,
          segments: segment.segments,
          words: segment.verse.words.map(&:text_qpc_hafs)
        }
      }
    }
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

  def load_audio_file
    Audio::ChapterAudioFile
      .includes(:chapter)
      .where(audio_recitation: @recitation.id, chapter_id: chapter_id)
      .first
  end

  def chapter_id
    if params[:verse_key].present?
      return params[:verse_key].split(':').first
    end

    params[:chapter_id] || params[:id]
  end

  def load_resource_access
    recitation_id = params[:recitation_id] || params[:id] || 7
    @recitation = Audio::Recitation.find(recitation_id)
    @resource = @recitation.get_resource_content
    @access = can_manage?(@resource)
  end

  def init_presenter
    @presenter = SurahAudioFilesPresenter.new(self)
  end
end