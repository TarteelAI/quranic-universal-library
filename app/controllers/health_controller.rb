class HealthController < ActionController::Base
  def show
    render json: { status: 'success' }
  end
end
