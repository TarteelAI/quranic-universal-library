class Segments::DashboardController < ApplicationController
  before_action :authenticate_user!
  before_action :authorize_access!
  before_action :check_segments_database, except: :setup_db

  def setup_db
    if request.post?
      uploaded_file = params[:file]

      if uploaded_file.present?
        save_path = upload_db(uploaded_file)
        redirect_to segments_dashboard_path, notice: "DB uploaded successfully to #{save_path}."
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
      logs = SegmentStats::Log
      logs = logs.where(surah_number: params[:surah])
      @logs = logs.where(reciter_id: params[:reciter])
    end
  end

  def failures
    @failures = SegmentStats::FailureStat

    if params[:surah].present?
      @failures = @failures.where(surah_number: params[:surah])
    end

    if params[:reciter].present?
      @failures = @failures.where(reciter_id: params[:reciter])
    end

    @pagy, @failures = pagy(@failures)
  end

  protected

  def authorize_access!
    unless current_user.super_admin? || current_user.is_admin?
      redirect_to root_path, alert: "You do not have permission to access this page."
    end
  end

  def check_segments_database
    models = segment_modals
    missing_models = models.reject { |model| model.table_exists? }

    if missing_models.any?
      missing_names = missing_models.map { |m| m.table_name }
      redirect_to segments_setup_db_path, alert: "Missing tables in segments DB: #{missing_names.join(', ')}. Please upload a valid DB." and return
    end
  end

  def segment_modals
    [
      SegmentStats::DetectionStat,
      SegmentStats::FailureStat,
      SegmentStats::SegmentLog,
      SegmentStats::PositionStat,
      SegmentStats::ReciterName
    ]
  end

  def upload_db(uploaded_file)
    save_path = Rails.root.join("db", "segments_database.db")

    File.open(save_path, "wb") do |file|
      file.write(uploaded_file.read)
    end

    segment_modals.each(&:reset_column_information)
    save_path
  end
end