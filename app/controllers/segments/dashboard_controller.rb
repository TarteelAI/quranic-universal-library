class Segments::DashboardController < ApplicationController
  before_action :authenticate_user!
  before_action :authorize_access!
  before_action :check_segments_database, except: :setup_db

  def setup_db
    if request.post?
      uploaded_file = params[:file]

      if uploaded_file.present?
        if (save_path = upload_db(uploaded_file))
          redirect_to segments_dashboard_path, notice: "DB uploaded successfully to #{save_path}."
        else
          redirect_to segments_setup_db_path, alert: "Failed to upload the database. Please ensure the file is a valid zip containing a .db file."
        end
      else
        redirect_to segments_setup_db_path, alert: "Please select a file."
      end
    end
  end

  def show
    @reciters = SegmentStats::ReciterName.all
    @surahs = SegmentStats::DetectionStat.distinct.pluck(:surah_number).sort

    selected_reciter = params[:reciter_id]
    selected_surah = params[:surah]

    stats = SegmentStats::DetectionStat.all
    stats = stats.where(reciter_id: selected_reciter.to_i) if selected_reciter.present?
    stats = stats.where(surah_number: selected_surah.to_i) if selected_surah.present?

    @detection_counts = stats.group(:detection_type).sum(:count)
    @failures = SegmentStats::FailureStat.all
    @failures = @failures.where(reciter_id: selected_reciter) if selected_reciter.present?
    @failures = @failures.where(surah_number: selected_surah) if selected_surah.present?

    @mistake_types = @failures.group(:failure_type).count

    @selected_reciter = selected_reciter.to_i
    @selected_surah = selected_surah.to_i

    @reciter_stats = SegmentStats::ReciterName.all.map do |reciter|
      {
        name: reciter.name,
        positions: SegmentStats::PositionStat.where(reciter_id: reciter.id).count,
        failures: SegmentStats::FailureStat.where(reciter_id: reciter.id).count
      }
    end
  end

  def reciters
    @selected_surah = params[:surah]

    @reciter_stats = SegmentStats::ReciterName.all.map do |reciter|
      positions = SegmentStats::PositionStat.where(reciter_id: reciter.id)
      failures = SegmentStats::FailureStat.where(reciter_id: reciter.id)

      if @selected_surah.present?
        positions = positions.where(surah_number: @selected_surah.to_i)
        failures = failures.where(surah_number: @selected_surah.to_i)
      end

      {
        name: reciter.name,
        positions: positions.count,
        failures: failures.count
      }
    end

    @surahs = SegmentStats::DetectionStat.distinct.pluck(:surah_number).sort
  end

  def timeline
    selected_reciter = params[:reciter_id]
    selected_surah = params[:surah]

    if selected_surah.present? && selected_reciter.present?
      @reciter = SegmentStats::ReciterName.find(selected_reciter)
      @failures = SegmentStats::FailureStat.where(reciter_id: @reciter.id, surah_number: selected_surah).index_by(&:word_key)
      @ayah_positions = SegmentStats::PositionStat.where(reciter_id: @reciter.id, surah_number: selected_surah).order(:ayah_number).group_by(&:ayah_number)
      @word_positions = SegmentStats::PositionStat.where(reciter_id: @reciter.id, surah_number: selected_surah).order(:ayah_number).index_by(&:word_key)
      @ayahs = Verse.where(chapter_id: selected_surah).order(:verse_number)
    end

    @selected_reciter = selected_reciter.to_i
    @selected_surah = selected_surah.to_i
  end

  def detections
    @reciters = SegmentStats::ReciterName.all
    @surahs = SegmentStats::DetectionStat.distinct.pluck(:surah_number).sort

    @selected_reciter = params[:reciter_id]
    @selected_surah = params[:surah]

    detections = SegmentStats::DetectionStat

    if @selected_reciter.present?
      detections = detections.where(reciter_id: @selected_reciter.to_i)
    end

    if @selected_surah.present?
      detections = detections.where(surah_number: @selected_surah.to_i)
    end

    @grouped_detections = detections.joins(:reciter)
                                    .select('reciters.name AS reciter_name, surah_number, detection_type, COUNT(*) AS total')
                                    .group('reciters.name, surah_number, detection_type')
                                    .order('reciters.name, surah_number')
  end

  def logs
    if params[:surah].blank? || params[:reciter].blank?
      flash[:alert] = "Please provide reciter and surah to view logs."
      @logs = []
    else
      logs = SegmentStats::SegmentLog
      logs = logs.where(surah_number: params[:surah])
      @logs = logs.where(reciter_id: params[:reciter])
    end
  end

  def failures
    selected_reciter = params[:reciter_id]
    selected_surah = params[:surah]
    @expected_text = params[:expected_text].to_s.strip
    @received_text = params[:received_text].to_s.strip
    @failure_type = params[:failure_type].to_s.strip

    @failures = SegmentStats::FailureStat
    @selected_reciter = selected_reciter.to_i
    @selected_surah = selected_surah.to_i

    if selected_surah.present?
      @failures = @failures.where(surah_number: @selected_surah)
    end

    if selected_reciter.present?
      @failures = @failures.where(reciter_id: @selected_reciter)
    end

    if @expected_text.present?
      @failures = @failures.where("expected_transcript LIKE ?", "%#{@expected_text}%")
    end

    if @received_text.present?
      @failures = @failures.where("received_transcript LIKE ?", "%#{@received_text}%")
    end

    if @failure_type.present?
      @failures = @failures.where(failure_type: @failure_type)
    end

    @pagy, @failures = pagy(@failures)
  end

  def ayah_report
    @ayah_failures = SegmentStats::FailureStat
                       .joins(:reciter)
                       .select(
                         'surah_number',
                         'ayah_number',
                         'GROUP_CONCAT(DISTINCT reciters.id) AS reciters',
                         'GROUP_CONCAT(DISTINCT failure_type) AS failure_types',
                         'COUNT(*) AS total_failures'
                       )
                       .group(:surah_number, :ayah_number)
                       .order(:surah_number, :ayah_number)
  end

  protected

  def authorize_access!
    unless current_user.super_admin? || current_user.is_admin?
      redirect_to root_path, alert: "You do not have permission to access this page."
    end
  end

  def check_segments_database
    models = segment_models
    missing_models = models.reject { |model| model.table_exists? }

    if missing_models.any?
      missing_names = missing_models.map { |m| m.table_name }
      redirect_to segments_setup_db_path, alert: "Missing tables in segments DB: #{missing_names.join(', ')}. Please upload a valid DB." and return
    end
  rescue SQLite3::CantOpenException => e
    redirect_to segments_setup_db_path, alert: "Segments database is missing" and return
  end

  def segment_models
    [
      SegmentStats::DetectionStat,
      SegmentStats::FailureStat,
      SegmentStats::SegmentLog,
      SegmentStats::PositionStat,
      SegmentStats::ReciterName
    ]
  end

  def upload_db(uploaded_file)
    require "zip"
    tmp_dir = Rails.root.join("tmp")
    db_output_path = tmp_dir.join("segments_database.db")
    zip_temp_path = tmp_dir.join("segments_upload.zip")

    File.open(zip_temp_path, "wb") { |f| f.write(uploaded_file.read) }

    db_file = nil
    Zip::File.open(zip_temp_path) do |zip_file|
      zip_file.each do |entry|
        if entry.name.ends_with?(".db")
          entry.extract(db_output_path) { true }
          db_file = db_output_path
          break
        end
      end
    end

    File.delete(zip_temp_path) if File.exist?(zip_temp_path)

    if db_file.present?
      SegmentStats::Base.establish_connection(
        adapter: 'sqlite3',
        database: db_file.to_s
      )

      segment_models.each(&:reset_column_information)
    end

    binding.pry

    db_file
  rescue StandardError => e
    # Do nothing
  end
end