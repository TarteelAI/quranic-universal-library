class Segments::DashboardController < ApplicationController
  before_action :init_presenter
  before_action :authenticate_user!
  before_action :authorize_access!
  before_action :check_segments_database, except: :setup_db

  def setup_db
    find_or_initialize_db

    if request.post?
      @db.active = true
      @db.save
      ::Segments::Database.where.not(id: @db.id).update_all(active: false)
      redirect_to segments_dashboard_path, notice: "DB uploaded successfully."
    end
  end

  def show
  end

  def reciters
  end

  def timeline
  end

  def detections
    @selected_reciter = params[:reciter_id]
    @selected_surah = params[:surah]

    detections = ::Segments::Detection

    if @selected_reciter.present?
      detections = detections.where(reciter_id: @selected_reciter.to_i)
    end

    if @selected_surah.present?
      detections = detections.where(surah_number: @selected_surah.to_i)
    end

    @grouped_detections = detections.joins(:reciter)
                                    .select('segments_reciters.name AS reciter_name, surah_number, detection_type, COUNT(*) AS total')
                                    .group('segments_reciters.name, surah_number, detection_type')
                                    .order('segments_reciters.name, surah_number')
  end

  def logs
    if params[:surah].blank? || params[:reciter].blank?
      flash[:alert] = "Please provide reciter and surah to view logs."
      @logs = []
    else
      logs = ::Segments::Log
      logs = logs.where(surah_number: params[:surah])
      @logs = logs.where(reciter_id: params[:reciter])
    end
  end

  def failures
  end

  def word_failures
  end

  def word_failure_detail
  end

  def ayah_report
  end

  protected

  def authorize_access!
    unless current_user.super_admin? || current_user.is_admin?
      redirect_to root_path, alert: "You do not have permission to access this page."
    end
  end

  def check_segments_database
    if ::Segments::Database.current.nil?
      return redirect_to segments_setup_db_path, alert: "Segments database is missing"
    end

    ::Segments::Database.current.load_db
  end

  def init_presenter
    @presenter = Segments::DashboardPresenter.new(self)
  end

  def segment_db_params
    if request.get?
      {}
    else
      params.require(:segments_database).permit(:db_file, :name)
    end
  end

  def find_or_initialize_db
    if request.get?
      @db = ::Segments::Database.new
    else
      if params[:id]
        @db = ::Segments::Database.find(params[:id])
      else
        @db = ::Segments::Database.new(segment_db_params)
      end
    end
  end
end