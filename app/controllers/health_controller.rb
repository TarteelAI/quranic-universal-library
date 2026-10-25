class HealthController < ActionController::Base
  def show
    if MaintenanceMode.on?
      render json: {
        status: 'maintenance',
        maintenance: true,
        message: MaintenanceMode.message,
        eta: MaintenanceMode.eta,
        started_at: MaintenanceMode.started_at
      }.compact, status: :service_unavailable
    else
      render json: { status: 'success', maintenance: false }
    end
  end
end
