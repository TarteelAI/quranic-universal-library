module Api
  module V1
    class ApiController < ActionController::API
      before_action :init_presenter
      before_action :set_cache_headers

      rescue_from ActiveRecord::RecordNotFound, with: :record_not_found
      rescue_from Api::RecordNotFound, with: :record_not_found
      rescue_from ActionController::ParameterMissing, with: :parameter_missing

      protected

      def set_cache_headers
        if Rails.env.production?
          if action_name != 'random'
            expires_in 7.day, public: true
            headers['Strict-Transport-Security'] = 'max-age=31536000; includeSubDomains; preload'
          end

          headers['Access-Control-Allow-Origin'] = '*'
        end
      end

      def render_json(data, status: :ok)
        render json: data, status: status
      end

      def record_not_found(exception)
        render_json(
          {
            error: "Not Found",
            message: exception.to_s
          },
          status: :not_found
        )
      end

      def parameter_missing(exception)
        render_json(
          {
            error: "Bad Request",
            message: exception.message
          },
          status: :bad_request
        )
      end
    end
  end
end