class Api::V1::ApplicationController < ActionController::API
  include ActionController::HttpAuthentication::Token::ControllerMethods
  include Api::ErrorHandling
  include Api::ResponseHelpers
  include Api::SerializationHelpers
  include Pundit::Authorization

  # Pagination settings
  ITEMS_PER_PAGE = 20
  MAX_ITEMS_PER_PAGE = 100

  before_action :authenticate_request, except: [:health]
  before_action :set_default_response_format
  before_action :set_current_attributes

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

  def set_current_attributes
    Current.user = current_user if @current_user
    Current.ip_address = request.remote_ip
    Current.user_agent = request.user_agent
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

  # Generic authorization callback for child controllers
  # Uses convention over configuration: action_name → policy_name
  # Child controllers can define POLICY_MAPPING constant for exceptions
  def authorize_resource
    # 1. Determine the resource instance variable based on controller name
    # Example: UsersController → @user, ProductionOrdersController → @production_order
    resource = instance_variable_get("@#{controller_name.singularize}")

    # 2. Get policy mapping from child controller if defined, otherwise use empty hash
    policy_mapping = defined?(self.class::POLICY_MAPPING) ? self.class::POLICY_MAPPING : {}

    # 3. Determine the policy rule name
    # Either from the mapping (for exceptions) or from the action name
    policy_action = policy_mapping[action_name.to_sym] || action_name
    policy_name = "#{policy_action}?"

    if resource
      # Instance authorization (when resource is already loaded)
      authorize resource, policy_name
    else
      # Class authorization (when resource hasn't been loaded yet, e.g., index, create)
      # Derive the model class from the controller name
      resource_class = controller_name.singularize.classify.constantize
      authorize resource_class, policy_name
    end
  rescue NameError => e
    # Handle cases where controller name doesn't map to a valid model class
    Rails.logger.error "Could not determine resource class for #{controller_name}: #{e.message}"
    raise Pundit::NotAuthorizedError, "Cannot authorize resource for #{controller_name}"
  end
end