class AyahAudioFilesController < CommunityController
  before_action :load_resource_access
  before_action :load_audio_files, only: [:show, :segments, :save_segments]
  before_action :authorize_access!, only: %i[save_segments]
  before_action :authenticate_user!, only: %i[save_segments]

  def index
    sort_key = params[:sort_key] || 'chapter_id'
    files = AudioFile.where(recitation_id: @recitation.id)

    if params[:filter_chapter].present?
      files = files.where(chapter_id: params[:filter_chapter])
    end

    if params[:verse_number].present?
      files = files.where(verse_number: params[:verse_number])
    end

    @pagy, @audio_files = pagy(files.includes(:verse).order("#{sort_key} #{sort_order}"))
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
    return @recitation if @recitation

    params[:id] ||= 7
    @recitation = Recitation.find(params[:id])
  end

  def load_resource_access
    recitation = load_recitation
    @resource = recitation.resource_content
    @access = can_manage?(@resource)
  end
end