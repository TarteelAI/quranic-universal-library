class AyahAudioFilesController < CommunityController
  before_action :authenticate_user!, only: %i[save_segments]
  before_action :load_recitation
  before_action :load_audio_files, only: [:show, :segments, :save_segments]
  before_action :check_permission, only: %i[save_segments]

  def index
    params[:sort_key] ||= 'chapter_id'
    params[:sort_order] ||= 'ASC'

    files = AudioFile.where(recitation_id: @recitation.id)

    if params[:filter_chapter].present?
      files = files.where(chapter_id: params[:filter_chapter])
    end

    if params[:verse_number].present?
      files = files.where(verse_number: params[:verse_number])
    end

    @pagy, @audio_files = pagy(files.includes(:verse).order("#{params[:sort_key]} #{params[:sort_order].presence}"))
  end

  def show
  end

  def segment_builder
    if params[:chapter_id].blank?
      params[:chapter_id] = 1
    end
    
    @chapter = Chapter.find(params[:chapter_id])
  end

  def segments
    @chapter = Chapter.find(params[:chapter_id])
    @verses = @chapter.verses.includes(:words)
                   .order('verses.id ASC')
  end

  def save_segments
    verse = Verse.find_by(verse_key: params[:verse_key].to_s.strip)
    segments = params[:segments]
    audio = AudioFile.where(verse: verse, recitation_id: params[:id]).first
    audio.set_segments(segments, current_user)

    render 'segments'
  end

  protected

  def load_audio_files
    if ['show', 'segment_builder'].include?(action_name) && params[:chapter_id].blank?
      params[:chapter_id] = 1
    end

    audio_files = AudioFile
                    .includes(verse: :words)
                    .where(
                      recitation_id: @recitation.id,
                      chapter_id: params[:chapter_id]
                    )

    @chapter = Chapter.find(params[:chapter_id]) if params[:chapter_id]

    if params[:sort_key].present?
      @audio_files = audio_files.order("audio_files.#{params[:sort_key]} #{params[:sort_order]}")
    else
      @audio_files = audio_files.order('audio_files.verse_number ASC')
    end
  end

  def load_recitation
    params[:id] ||= 7

    @recitation = Recitation.find(params[:id])
    @has_permission = can_manage?(@recitation.resource_content)
  end

  def check_permission
    if !@has_permission
      if request.format.turbo_stream?
        render turbo_stream: turbo_stream.replace('flash-messages', partial: 'shared/permission_denied')
      else
        render json: { error: 'Permission Denied' }
      end
    end
  end
end