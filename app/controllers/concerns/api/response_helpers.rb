module Api
  module ResponseHelpers
    extend ActiveSupport::Concern

    # Success responses
    def render_success(data = nil, message = nil, status = :ok, meta = {})
      response = {
        success: true,
        timestamp: Time.current.iso8601
      }
      
      response[:message] = message if message
      response[:data] = data if data
      response[:meta] = meta if meta.any?
      
      render json: response, status: status
    end

    # Paginated success responses
    def render_paginated_success(data, pagination_object, message = nil)
      render_success(
        data,
        message,
        :ok,
        build_pagination_meta(pagination_object)
      )
    end

    # Error responses (complementing the error handling concern)
    def render_error(message, status = :bad_request, errors = nil, code = nil)
      response = {
        success: false,
        message: message,
        timestamp: Time.current.iso8601
      }
      
      response[:code] = code if code
      response[:errors] = errors if errors
      
      render json: response, status: status
    end

    # Validation error responses
    def render_validation_errors(record)
      render_error(
        'Validation failed',
        :unprocessable_content,
        format_validation_errors(record),
        'VALIDATION_ERROR'
      )
    end

    # Not found responses
    def render_not_found(resource_type = 'Resource')
      render_error(
        "#{resource_type} not found",
        :not_found,
        nil,
        'RESOURCE_NOT_FOUND'
      )
    end

    # Authorization error responses
    def render_unauthorized(message = 'You are not authorized to perform this action')
      render_error(
        message,
        :forbidden,
        nil,
        'AUTHORIZATION_ERROR'
      )
    end

    # Created responses
    def render_created(data, message = 'Resource created successfully')
      render_success(data, message, :created)
    end

    # No content responses (for deletions)
    def render_deleted(message = 'Resource deleted successfully')
      render json: {
        success: true,
        message: message,
        timestamp: Time.current.iso8601
      }, status: :ok
    end

    private

    def build_pagination_meta(pagination_object)
      {
        pagination: {
          current_page: pagination_object.current_page,
          total_pages: pagination_object.total_pages,
          total_count: pagination_object.total_count,
          per_page: pagination_object.limit_value,
          has_next_page: pagination_object.next_page.present?,
          has_prev_page: pagination_object.prev_page.present?,
          next_page: pagination_object.next_page,
          prev_page: pagination_object.prev_page
        }
      }
    end

    def format_validation_errors(record)
      if record.errors.respond_to?(:details)
        # Detailed error format
        record.errors.details.map do |field, errors|
          errors.map do |error|
            {
              field: field,
              code: error[:error],
              message: record.errors.full_message(field, error[:error])
            }
          end
        end.flatten
      else
        # Simple error format
        record.errors.full_messages
      end
    end
  end
end