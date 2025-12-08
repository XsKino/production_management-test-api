module Api
  module ErrorHandling
    extend ActiveSupport::Concern

    included do
      rescue_from StandardError do |exception|
        handle_standard_error(exception)
      end

      rescue_from ActiveRecord::RecordNotFound do |exception|
        render_error_response(
          message: 'Resource not found',
          status: :not_found,
          code: 'RESOURCE_NOT_FOUND',
          details: exception.message
        )
      end

      rescue_from ActiveRecord::RecordInvalid do |exception|
        render_error_response(
          message: 'Validation failed',
          status: :unprocessable_content,
          code: 'VALIDATION_ERROR',
          errors: exception.record.errors.full_messages
        )
      end

      rescue_from ActiveRecord::RecordNotDestroyed do |exception|
        render_error_response(
          message: 'Failed to destroy the record',
          status: :unprocessable_content,
          code: 'RECORD_NOT_DESTROYED',
          errors: exception.record.errors.full_messages
        )
      end

      rescue_from ActiveRecord::RecordNotSaved do |exception|
        render_error_response(
          message: 'Failed to save the record',
          status: :unprocessable_content,
          code: 'RECORD_NOT_SAVED',
          errors: exception.record.errors.full_messages
        )
      end

      rescue_from ActionController::ParameterMissing do |exception|
        render_error_response(
          message: "Required parameter missing: #{exception.param}",
          status: :bad_request,
          code: 'PARAMETER_MISSING',
          details: exception.message
        )
      end
      

      rescue_from Pundit::NotAuthorizedError do |exception|
        render_error_response(
          message: 'You are not authorized to perform this action',
          status: :forbidden,
          code: 'AUTHORIZATION_ERROR',
          details: exception.message
        )
      end

      rescue_from ArgumentError do |exception|
        render_error_response(
          message: 'Invalid argument provided',
          status: :bad_request,
          code: 'INVALID_ARGUMENT',
          details: exception.message
        )
      end
    end

    private

    def handle_standard_error(exception)
      # Log the error for debugging
      Rails.logger.error("API Error: #{exception.class} - #{exception.message}")
      Rails.logger.error(exception.backtrace.join("\n"))

      # Return generic error in production, detailed error in development
      if Rails.env.production?
        render_error_response(
          message: 'An internal server error occurred',
          status: :internal_server_error,
          code: 'INTERNAL_ERROR'
        )
      else
        render_error_response(
          message: exception.message,
          status: :internal_server_error,
          code: 'INTERNAL_ERROR',
          details: {
            class: exception.class.name,
            backtrace: exception.backtrace&.first(10)
          }
        )
      end
    end

    def render_error_response(message:, status:, code: nil, errors: nil, details: nil)
      response = {
        success: false,
        message: message,
        timestamp: Time.current.iso8601
      }
      
      response[:code] = code if code
      response[:errors] = errors if errors
      response[:details] = details if details && !Rails.env.production?
      
      render json: response, status: status
    end
  end
end