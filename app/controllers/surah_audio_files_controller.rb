class SurahAudioFilesController < CommunityController
  before_action :authenticate_user!, only: [:save_segments]
  before_action :authorize_access!, only: [:save_segments]
  before_action :init_presenter

  def builder_help
    render layout: false
  end

  def index
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

    if @audio_file.nil?
      redirect_to surah_audio_files_path(
        recitation_id: @recitation.id
      ), alert: 'Audio file not found'
    end
  end

  def segments
    @audio_file = load_audio_file

    @verses = Verse.includes(:words)
                   .where(chapter_id: @audio_file.chapter_id)
                   .order('verses.id ASC')
  end

  def validate_segments
    @audio_file = load_audio_file
    return render(json: { issues: [] }) if @audio_file.nil?

    issues =
      if params[:segments].present?
        validate_posted_segments(@audio_file, params[:segments])
      else
        @recitation.validate_segments_data(audio_file: @audio_file)
      end

    render json: { issues: issues.map { |issue| serialize_issue(issue) } }
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

  def validate_posted_segments(audio_file, posted)
    chapter = audio_file.chapter
    verses_by_number = Verse.where(chapter_id: chapter.id).index_by(&:verse_number)

    segments = posted.to_unsafe_h.map do |verse_key, data|
      verse_number = verse_key.to_s.split(':').last.to_i
      verse = verses_by_number[verse_number]

      Audio::SegmentValidator::SegmentData.new(
        verse_key: verse_key.to_s,
        chapter_id: chapter.id,
        verse_number: verse_number,
        timestamp_from: cast_ms(data['timestamp_from']),
        timestamp_to: cast_ms(data['timestamp_to']),
        words_count: verse&.words_count.to_i,
        word_segments: cast_word_segments(data['segments']),
        audio_file_id: audio_file.id,
        audio_duration_ms: audio_file.duration_ms
      )
    end

    Audio::SegmentValidator.new(segments, expected_verses_count: chapter.verses_count).validate
  end

  def serialize_issue(issue)
    verse_number = issue[:key] ? issue[:key].to_s.split(':').last.to_i : nil
    issue.merge(verse: verse_number)
  end

  def cast_ms(value)
    return nil if value.nil? || value == ''

    Integer(value)
  rescue ArgumentError, TypeError
    value.to_i
  end

  def cast_word_segments(segments)
    return [] if segments.blank?

    Array(segments).map do |word_segment|
      word_segment = word_segment.values if word_segment.respond_to?(:values)
      [word_segment[0], cast_ms(word_segment[1]), cast_ms(word_segment[2])]
    end
  end

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