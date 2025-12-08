class Api::V1::ProductionOrdersController < Api::V1::ApplicationController
  # Define exceptions where action name doesn't match the policy name
  POLICY_MAPPING = {
    audit_logs: :show # audit_logs validates against show? rule
  }.freeze

  # Important order: First fetch, then authorize
  before_action :set_order_type, only: [:index, :create]
  before_action :set_production_order, only: [:show, :update, :destroy, :tasks_summary, :audit_logs]

  # This callback uses the generic authorize_resource from ApplicationController
  before_action :authorize_resource, except: [:create]

  # GET /api/v1/production_orders
  # GET /api/v1/normal_orders
  # GET /api/v1/urgent_orders
  def index
    # Apply Pundit scope
    @orders = policy_scope(ProductionOrder)

    # Apply type filter if accessing specific order type routes
    @orders = @orders.where(type: @order_type) if @order_type

    # Apply Ransack filtering
    @orders = apply_ransack_filters(@orders, order_ransack_params)

    # Apply pagination
    @orders = paginate_collection(@orders.includes(:creator, :assigned_users, :tasks))

    # Prepare response with pagination metadata
    render_success(
      serialize_orders(@orders),
      nil,
      :ok,
      pagination_meta(@orders)
    )
  end

  # GET /api/v1/production_orders/:id
  def show
    render_success(serialize_order_with_tasks(@production_order))
  end

  # POST /api/v1/production_orders
  # POST /api/v1/normal_orders
  # POST /api/v1/urgent_orders
  def create
    order_class = @order_type&.constantize || NormalOrder
    @production_order = order_class.new(production_order_params)
    @production_order.creator = current_user

    # Manual authorization: need to authorize the instance with user-provided data before saving
    authorize @production_order

    @production_order.save!

    # Assign users if provided
    assign_users if order_assignment_params[:user_ids].present?

    # Invalidate monthly statistics cache
    invalidate_monthly_statistics_cache

    render_success(
      serialize_order_with_tasks(@production_order),
      'Production order created successfully',
      :created
    )
  end

  # PATCH/PUT /api/v1/production_orders/:id
  def update
    @production_order.update!(production_order_params)

    # Update assignments if provided
    update_assignments if order_assignment_params[:user_ids]

    # Invalidate monthly statistics cache
    invalidate_monthly_statistics_cache

    render_success(
      serialize_order_with_tasks(@production_order),
      'Production order updated successfully'
    )
  end

  # DELETE /api/v1/production_orders/:id
  def destroy
    @production_order.destroy!

    # Invalidate monthly statistics cache
    invalidate_monthly_statistics_cache

    render_success(nil, 'Production order deleted successfully')
  end

  # GET /api/v1/production_orders/:id/tasks_summary
  def tasks_summary
    summary = {
      order: serialize_order(@production_order),
      tasks_summary: {
        total_tasks: @production_order.tasks.count,
        pending_tasks: @production_order.tasks.pending.count,
        completed_tasks: @production_order.tasks.completed.count,
        completion_percentage: calculate_completion_percentage(@production_order),
        latest_pending_task_date: @production_order.tasks.pending.maximum(:expected_end_date),
        overdue_tasks: @production_order.tasks.where('expected_end_date < ? AND status = ?',
                                                    Date.current, Task.statuses[:pending]).count
      }
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
    cache_key = monthly_statistics_cache_key(current_user, current_month_start)

    # Cache expires at the end of current month
    expires_at = current_month_end.end_of_day

    stats = Rails.cache.fetch(cache_key, expires_at: expires_at) do
      # Get orders accessible to current user
      base_orders = policy_scope(ProductionOrder)

      {
        current_month: {
          normal_orders_starting: base_orders.where(type: 'NormalOrder')
                                            .where(start_date: current_month_start..current_month_end)
                                            .count,
          urgent_orders_with_deadline: base_orders.where(type: 'UrgentOrder')
                                                 .where(deadline: current_month_start..current_month_end)
                                                 .count,
          total_orders_started: base_orders.where(start_date: current_month_start..current_month_end).count,
          completed_orders: base_orders.where(status: :completed)
                                     .where(updated_at: current_month_start..current_month_end)
                                     .count
        }
      }
    end

    render_success(stats)
  end

  # GET /api/v1/production_orders/urgent_orders_report
  def urgent_orders_report
    # Store statuses in variables for clean interpolation
    pending_status = Task.statuses[:pending]
    completed_status = Task.statuses[:completed]

    # Define Lateral Join
    # Fetches the latest pending task specific to the current order
    lateral_join_sql = <<~SQL
      LEFT JOIN LATERAL (
        SELECT
          id,
          description,
          expected_end_date,
          status,
          created_at,
          updated_at
        FROM tasks
        WHERE tasks.production_order_id = production_orders.id
          AND tasks.status = #{pending_status}
        ORDER BY id DESC
        LIMIT 1
      ) AS latest_task ON true
    SQL

    # Build the Query
    urgent_orders_with_stats = policy_scope(ProductionOrder)
      .joins("LEFT JOIN tasks ON tasks.production_order_id = production_orders.id") # Join 1: To count global statistics
      .joins(lateral_join_sql) # Join 2: To fetch specific fields of the latest task
      .where(type: 'UrgentOrder')
      .select(
        "production_orders.*",

        # Latest pending task fields (use ANY_VALUE to avoid GROUP BY errors)
        "ANY_VALUE(latest_task.id) as latest_pending_task_id",
        "ANY_VALUE(latest_task.description) as latest_pending_task_description",
        "ANY_VALUE(latest_task.expected_end_date) as latest_pending_task_expected_end_date",
        "ANY_VALUE(latest_task.status) as latest_pending_task_status",
        "ANY_VALUE(latest_task.created_at) as latest_pending_task_created_at",
        "ANY_VALUE(latest_task.updated_at) as latest_pending_task_updated_at",

        # Aggregated Statistics (using 'tasks' table from first join)
        "COUNT(CASE WHEN tasks.status = #{pending_status} THEN 1 END) as pending_tasks_count",
        "COUNT(CASE WHEN tasks.status = #{completed_status} THEN 1 END) as completed_tasks_count",
        "COUNT(tasks.id) as total_tasks_count",
        "CASE
           WHEN COUNT(tasks.id) > 0
           THEN ROUND(COUNT(CASE WHEN tasks.status = #{completed_status} THEN 1 END) * 100.0 / COUNT(tasks.id), 2)
           ELSE 0
         END as completion_percentage"
      )
      .group("production_orders.id")
      .includes(:creator, :assigned_users)

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
    # Find urgent orders with at least one pending task that's overdue
    urgent_orders_with_expired = policy_scope(ProductionOrder)
      .joins(:tasks)
      .where(type: 'UrgentOrder')
      .where(tasks: { 
        status: Task.statuses[:pending],
        expected_end_date: ...Date.current 
      })
      .distinct
      .includes(:creator, :assigned_users, :tasks)

    paginated_orders = paginate_collection(urgent_orders_with_expired)
    
    serialized_orders = paginated_orders.map do |order|
      expired_tasks = order.tasks.pending.where('expected_end_date < ?', Date.current)
      
      serialize_order(order).merge({
        expired_tasks_count: expired_tasks.count,
        expired_tasks: expired_tasks.map { |task| serialize_task(task) }
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

  def set_order_type
    # Determine order type from route or params
    @order_type = case params[:controller]
                  when 'api/v1/normal_orders'
                    'NormalOrder'
                  when 'api/v1/urgent_orders'
                    'UrgentOrder'
                  else
                    params[:production_order]&.[](:type) || params[:type]
                  end
  end

  def production_order_params
    permitted_params = [:start_date, :expected_end_date, :status,
                       tasks_attributes: [:id, :description, :expected_end_date, :status, :_destroy]]

    # Add deadline for urgent orders
    permitted_params << :deadline if @order_type == 'UrgentOrder' || params.dig(:production_order, :type) == 'UrgentOrder'

    params.require(:production_order).permit(permitted_params)
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

  def assign_users
    user_ids = order_assignment_params[:user_ids].compact.uniq
    user_ids.each do |user_id|
      @production_order.order_assignments.find_or_create_by(user_id: user_id)
    end
  end

  def update_assignments
    # Remove existing assignments
    @production_order.order_assignments.destroy_all
    
    # Add new assignments
    assign_users if order_assignment_params[:user_ids].present?
  end

  # Serialization methods
  def serialize_orders(orders)
    serializer_class = orders.first&.class == UrgentOrder ? UrgentOrderSerializer : ProductionOrderSerializer
    serializer_class.new(orders, include: [:creator, :assigned_users])
                    .serializable_hash[:data]
                    .map { |o| format_order_data(o) }
  end

  def serialize_order(order)
    serializer_class = order.is_a?(UrgentOrder) ? UrgentOrderSerializer : ProductionOrderSerializer
    data = serializer_class.new(order, include: [:creator, :assigned_users])
                           .serializable_hash
    format_order_data(data[:data])
  end

  def serialize_order_with_tasks(order)
    serializer_class = order.is_a?(UrgentOrder) ? UrgentOrderSerializer : ProductionOrderSerializer
    data = serializer_class.new(order, include: [:creator, :assigned_users, :tasks])
                           .serializable_hash
    formatted = format_order_data(data[:data], data[:included])

    formatted.merge({
      tasks_summary: {
        total: order.tasks.size,
        pending: order.tasks.select(&:pending?).size,
        completed: order.tasks.select(&:completed?).size,
        completion_percentage: calculate_completion_percentage(order)
      }
    })
  end

  def serialize_task(task)
    TaskSerializer.new(task).serializable_hash[:data][:attributes].merge({
      is_overdue: task.expected_end_date < Date.current && task.pending?
    })
  end

  private

  def format_order_data(data, included = nil)
    attributes = data[:attributes]
    relationships = data[:relationships] || {}

    result = attributes.dup

    # Format creator
    if relationships[:creator] && included
      creator_data = included.find { |i| i[:type] == :user && i[:id] == relationships[:creator][:data][:id].to_s }
      result[:creator] = creator_data[:attributes] if creator_data
    end

    # Format assigned_users
    if relationships[:assigned_users] && included
      result[:assigned_users] = relationships[:assigned_users][:data].map do |user_ref|
        user_data = included.find { |i| i[:type] == :user && i[:id] == user_ref[:id].to_s }
        user_data[:attributes] if user_data
      end.compact
    end

    # Format tasks if included
    if relationships[:tasks] && included
      result[:tasks] = relationships[:tasks][:data].map do |task_ref|
        task_data = included.find { |i| i[:type] == :task && i[:id] == task_ref[:id].to_s }
        task_data[:attributes].merge({
          is_overdue: task_data[:attributes][:expected_end_date] < Date.current &&
                     task_data[:attributes][:status] == 'pending'
        }) if task_data
      end.compact
    end

    result
  end

  def calculate_completion_percentage(order)
    total_tasks = order.tasks.size
    return 0 if total_tasks.zero?

    completed_tasks = order.tasks.select(&:completed?).size
    (completed_tasks.to_f / total_tasks * 100).round(2)
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

  # Generate cache key for monthly statistics
  # Key format: monthly_stats/{role}/{user_id_if_operator}/{year}/{month}
  def monthly_statistics_cache_key(user, month_start)
    key_parts = ['monthly_stats', user.role, month_start.year, month_start.month]

    # Operators only see their own orders, so include user_id in cache key
    key_parts.insert(2, user.id) if user.operator?

    key_parts.join('/')
  end

  # Invalidate monthly statistics cache for current month
  def invalidate_monthly_statistics_cache
    current_month_start = Date.current.beginning_of_month

    # Invalidate cache for all roles that might be affected
    # Admins and production_managers see all orders, so invalidate their cache
    %w[admin production_manager].each do |role|
      cache_key = ['monthly_stats', role, current_month_start.year, current_month_start.month].join('/')
      Rails.cache.delete(cache_key)
    end

    # For operators, invalidate cache for creator and assigned users
    if @production_order
      # Invalidate creator's cache if they're an operator
      if @production_order.creator&.operator?
        cache_key = ['monthly_stats', 'operator', @production_order.creator.id,
                     current_month_start.year, current_month_start.month].join('/')
        Rails.cache.delete(cache_key)
      end

      # Invalidate assigned operators' cache
      @production_order.assigned_users.where(role: :operator).each do |user|
        cache_key = ['monthly_stats', 'operator', user.id,
                     current_month_start.year, current_month_start.month].join('/')
        Rails.cache.delete(cache_key)
      end
    end
  end
end