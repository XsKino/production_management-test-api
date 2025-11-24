class Api::V1::ApplicationController < ActionController::API
  include ActionController::HttpAuthentication::Token::ControllerMethods
  include Api::ErrorHandling
  include Api::ResponseHelpers
  include Pundit::Authorization

  # Pagination settings
  ITEMS_PER_PAGE = 20
  MAX_ITEMS_PER_PAGE = 100

  before_action :authenticate_request, except: [:health]
  before_action :set_default_response_format

  # Pundit authorization error handling
  rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized

  # Health check endpoint (public)
  def health
    render json: {
      status: 'ok',
      timestamp: Time.current,
      version: '1.0.0'
    }
  end

  protected

  def authenticate_request
    token = request.headers['Authorization']&.split(' ')&.last

    if token.present?
      decoded = JsonWebToken.decode(token)

      if decoded
        @current_user = User.find_by(id: decoded[:user_id])
      end
    end

    unless @current_user
      render_error('Unauthorized', :unauthorized, nil, 'UNAUTHORIZED')
    end
  end

  def current_user
    @current_user
  end

  def set_default_response_format
    request.format = :json
  end

  def user_not_authorized
    render_error('You are not authorized to perform this action', :forbidden, nil, 'FORBIDDEN')
  end

  # Pagination helper
  def paginate_collection(collection)
    page = params[:page]&.to_i || 1
    per_page = [params[:per_page]&.to_i || ITEMS_PER_PAGE, MAX_ITEMS_PER_PAGE].min
    
    collection.page(page).per(per_page)
  end

  # Ransack filtering helper
  def apply_ransack_filters(collection, allowed_params = {})
    q = collection.ransack(filter_params(allowed_params))
    q.result(distinct: true)
  end

  def filter_params(allowed_params = {})
    return {} unless params[:q]

    # Default allowed ransack params for production orders
    default_allowed = {
      status_eq: nil,
      type_eq: nil,
      start_date_gteq: nil,
      start_date_lteq: nil,
      expected_end_date_gteq: nil,
      expected_end_date_lteq: nil,
      creator_id_eq: nil,
      order_number_eq: nil
    }

    allowed = default_allowed.merge(allowed_params)
    params[:q].permit(allowed.keys)
  end

  # Pagination metadata helper
  def pagination_meta(collection)
    {
      pagination: {
        current_page: collection.current_page,
        total_pages: collection.total_pages,
        total_count: collection.total_count,
        per_page: collection.limit_value,
        has_next_page: collection.next_page.present?,
        has_prev_page: collection.prev_page.present?
      }
    }
  end
end