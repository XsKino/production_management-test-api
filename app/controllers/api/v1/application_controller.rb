class Api::V1::ApplicationController < ActionController::API
  include ActionController::HttpAuthentication::Token::ControllerMethods
  include Api::ErrorHandling
  include Api::ResponseHelpers
  
  # Pagination settings
  ITEMS_PER_PAGE = 20
  MAX_ITEMS_PER_PAGE = 100

  before_action :authenticate_request
  before_action :set_default_response_format

  protected

  def authenticate_request
    # TODO: Implement actual authentication
    # we'll use a simple header-based auth for testing for now
    token = request.headers['Authorization']&.split(' ')&.last
    
    if token.present?
      # Simple token validation - replace with actual JWT or session validation
      @current_user = User.find_by(id: token) if token.match?(/^\d+$/)
    end
    
    render json: { error: 'Unauthorized' }, status: :unauthorized unless @current_user
  end

  def current_user
    @current_user
  end

  def set_default_response_format
    request.format = :json
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

  # Health check endpoint
  def health
    render json: { 
      status: 'ok', 
      timestamp: Time.current,
      version: '1.0.0'
    }
  end
end