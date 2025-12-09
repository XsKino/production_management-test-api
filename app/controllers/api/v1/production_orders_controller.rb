class Api::V1::ProductionOrdersController < Api::V1::ApplicationController
  # Define exceptions where action name doesn't match the policy name
  POLICY_MAPPING = {
    audit_logs: :show # audit_logs validates against show? rule
  }.freeze

  # Important order: First fetch, then authorize
  before_action :set_production_order, only: [:show, :update, :destroy, :tasks_summary, :audit_logs]

  # This callback uses the generic authorize_resource from ApplicationController
  before_action :authorize_resource, except: [:create]

  # GET /api/v1/production_orders
  # GET /api/v1/normal_orders (via NormalOrdersController)
  # GET /api/v1/urgent_orders (via UrgentOrdersController)
  def index
    # Apply Pundit scope
    @orders = policy_scope(ProductionOrder)

    # Apply type filter for specific order type controllers
    @orders = @orders.where(type: order_class.name) if respond_to?(:order_class, true)

    # Apply Ransack filtering
    @orders = apply_ransack_filters(@orders, order_ransack_params)

    # Apply pagination
    @orders = paginate_collection(@orders.includes(:creator, :assigned_users, :tasks))

    # Prepare response with pagination metadata
    render_success(
      serialize(@orders, include: [:creator, :assigned_users]),
      nil,
      :ok,
      pagination_meta(@orders)
    )
  end

  # GET /api/v1/production_orders/:id
  def show
    serialized = serialize(@production_order, include: [:creator, :assigned_users, :tasks])
    render_success(serialized.merge(tasks_summary: @production_order.tasks_summary))
  end

  # POST /api/v1/production_orders
  # POST /api/v1/normal_orders (via NormalOrdersController)
  # POST /api/v1/urgent_orders (via UrgentOrdersController)
  def create
    # Determine the order class:
    # 1. Use order_class from child controller if available (NormalOrdersController/UrgentOrdersController)
    # 2. Otherwise, check params[:production_order][:type] for explicit type specification
    # 3. Default to NormalOrder if neither is specified
    klass = if respond_to?(:order_class, true)
              order_class
            elsif params.dig(:production_order, :type).present?
              # Safe constantize with whitelist
              type_param = params.dig(:production_order, :type)
              case type_param
              when 'NormalOrder'
                NormalOrder
              when 'UrgentOrder'
                UrgentOrder
              else
                NormalOrder # Default fallback
              end
            else
              NormalOrder # Default
            end

    # Build temporary instance to determine permitted attributes (needed for UrgentOrder check)
    temp_order = klass.new
    permitted_attrs = policy(temp_order).permitted_attributes_for_create

    @production_order = klass.new(params.require(:production_order).permit(permitted_attrs))
    @production_order.creator = current_user

    # Manual authorization: need to authorize the instance with user-provided data before saving
    authorize @production_order

    @production_order.save!

    # Assign users if provided
    if order_assignment_params[:user_ids].present?
      @production_order.assign_users!(order_assignment_params[:user_ids])
      # Force reload of associations to ensure they're included
      @production_order.assigned_users.reload
    end

    # Invalidate monthly statistics cache
    MonthlyStatisticsCacheService.invalidate(@production_order)

    serialized = serialize(@production_order, include: [:creator, :assigned_users, :tasks])
    render_success(
      serialized.merge(tasks_summary: @production_order.tasks_summary),
      'Production order created successfully',
      :created
    )
  end

  # PATCH/PUT /api/v1/production_orders/:id
  def update
    permitted_attrs = policy(@production_order).permitted_attributes_for_update
    @production_order.update!(params.require(:production_order).permit(permitted_attrs))

    # Update assignments if provided
    @production_order.update_assignments!(order_assignment_params[:user_ids]) if order_assignment_params[:user_ids]

    # Invalidate monthly statistics cache
    MonthlyStatisticsCacheService.invalidate(@production_order)

    serialized = serialize(@production_order, include: [:creator, :assigned_users, :tasks])
    render_success(
      serialized.merge(tasks_summary: @production_order.tasks_summary),
      'Production order updated successfully'
    )
  end

  # DELETE /api/v1/production_orders/:id
  def destroy
    @production_order.destroy!

    # Invalidate monthly statistics cache
    MonthlyStatisticsCacheService.invalidate(@production_order)

    render_success(nil, 'Production order deleted successfully')
  end

  # GET /api/v1/production_orders/:id/tasks_summary
  def tasks_summary
    summary = {
      order: serialize(@production_order, include: [:creator, :assigned_users]),
      tasks_summary: @production_order.tasks_summary
    }

    render_success(summary)
  end

  # GET /api/v1/production_orders/:id/audit_logs
  def audit_logs
    @audit_logs = @production_order.audit_logs
                                   .includes(:user)
                                   .recent

    # Apply pagination
    @audit_logs = paginate_collection(@audit_logs)

    render_success(
      serialize_audit_logs(@audit_logs),
      nil,
      :ok,
      pagination_meta(@audit_logs)
    )
  end

  # GET /api/v1/production_orders/monthly_statistics
  def monthly_statistics
    current_month_start = Date.current.beginning_of_month
    current_month_end = Date.current.end_of_month

    # Cache key based on user role, user ID (for operators), and current month
    cache_key = MonthlyStatisticsCacheService.build_key(current_user, current_month_start)

    # Cache expires at the end of current month
    expires_at = current_month_end.end_of_day

    stats = Rails.cache.fetch(cache_key, expires_at: expires_at) do
      # Get orders accessible to current user and delegate to model
      base_orders = policy_scope(ProductionOrder)
      ProductionOrder.monthly_statistics_for(base_orders, current_month_start, current_month_end)
    end

    render_success(stats)
  end

  # GET /api/v1/production_orders/urgent_orders_report
  def urgent_orders_report
    # Delegate complex query to model
    urgent_orders_with_stats = ProductionOrder.urgent_orders_with_report(policy_scope(ProductionOrder))

    paginated_orders = paginate_collection(urgent_orders_with_stats)

    # Serialize manually without accessing tasks collection
    # since we have the counts from SQL aggregations
    serialized_orders = paginated_orders.map do |order|
      # Build latest_pending_task object if it exists
      latest_pending_task = if order.latest_pending_task_id.present?
        {
          id: order.latest_pending_task_id,
          description: order.latest_pending_task_description,
          expected_end_date: order.latest_pending_task_expected_end_date,
          status: Task.statuses.key(order.latest_pending_task_status),
          created_at: order.latest_pending_task_created_at,
          updated_at: order.latest_pending_task_updated_at
        }
      else
        nil
      end

      {
        id: order.id,
        type: order.type,
        order_number: order.order_number,
        start_date: order.start_date,
        expected_end_date: order.expected_end_date,
        deadline: order.deadline,
        status: order.status,
        created_at: order.created_at,
        updated_at: order.updated_at,
        creator: {
          id: order.creator.id,
          name: order.creator.name,
          email: order.creator.email
        },
        assigned_users: order.assigned_users.map { |u| { id: u.id, name: u.name, email: u.email } },
        latest_pending_task: latest_pending_task,
        pending_tasks_count: order.pending_tasks_count.to_i,
        completed_tasks_count: order.completed_tasks_count.to_i,
        total_tasks_count: order.total_tasks_count.to_i,
        completion_percentage: order.completion_percentage.to_f,
        days_until_deadline: order.deadline ? (order.deadline - Date.current).to_i : nil
      }
    end

    render_success(
      serialized_orders,
      nil,
      :ok,
      pagination_meta(paginated_orders)
    )
  end

  # GET /api/v1/production_orders/urgent_with_expired_tasks
  def urgent_with_expired_tasks
    # Delegate query to model
    urgent_orders_with_expired = ProductionOrder.urgent_with_expired_tasks(policy_scope(ProductionOrder))

    paginated_orders = paginate_collection(urgent_orders_with_expired)
    
    serialized_orders = paginated_orders.map do |order|
      expired_tasks = order.tasks.pending.where('expected_end_date < ?', Date.current)

      serialize(order, include: [:creator, :assigned_users]).merge({
        expired_tasks_count: expired_tasks.count,
        expired_tasks: expired_tasks.map { |task|
          serialize(task).merge(is_overdue: task.expected_end_date < Date.current && task.pending?)
        }
      })
    end

    render_success(
      serialized_orders,
      nil,
      :ok,
      pagination_meta(paginated_orders)
    )
  end

  private

  def set_production_order
    # Clean: only fetches the record
    @production_order = policy_scope(ProductionOrder).find(params[:id])
  end

  def order_assignment_params
    params.permit(user_ids: [])
  end

  def order_ransack_params
    {
      status_eq: nil,
      type_eq: nil,
      start_date_gteq: nil,
      start_date_lteq: nil,
      expected_end_date_gteq: nil,
      expected_end_date_lteq: nil,
      deadline_gteq: nil,
      deadline_lteq: nil,
      creator_id_eq: nil,
      order_number_eq: nil,
      assigned_users_id_eq: nil
    }
  end

  def serialize_audit_logs(audit_logs)
    audit_logs.map do |log|
      {
        id: log.id,
        action: log.action,
        change_details: log.change_details,
        user: {
          id: log.user.id,
          name: log.user.name,
          email: log.user.email
        },
        ip_address: log.ip_address,
        user_agent: log.user_agent,
        created_at: log.created_at
      }
    end
  end
end