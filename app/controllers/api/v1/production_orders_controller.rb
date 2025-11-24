class Api::V1::ProductionOrdersController < Api::V1::ApplicationController
  before_action :set_production_order, only: [:show, :update, :destroy, :tasks_summary]
  before_action :set_order_type, only: [:index, :create]

  # GET /api/v1/production_orders
  # GET /api/v1/normal_orders
  # GET /api/v1/urgent_orders
  def index
    authorize ProductionOrder

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
    authorize @production_order
    render_success(serialize_order_with_tasks(@production_order))
  end

  # POST /api/v1/production_orders
  # POST /api/v1/normal_orders
  # POST /api/v1/urgent_orders
  def create
    order_class = @order_type&.constantize || NormalOrder
    @production_order = order_class.new(production_order_params)
    @production_order.creator = current_user

    authorize @production_order

    if @production_order.save
      # Assign users if provided
      assign_users if order_assignment_params[:user_ids].present?
      
      render_success(
        serialize_order_with_tasks(@production_order),
        'Production order created successfully',
        :created
      )
    else
      render_error(
        'Failed to create production order',
        :unprocessable_content,
        @production_order.errors.full_messages
      )
    end
  end

  # PATCH/PUT /api/v1/production_orders/:id
  def update
    authorize @production_order

    if @production_order.update(production_order_params)
      # Update assignments if provided
      update_assignments if order_assignment_params[:user_ids]
      
      render_success(
        serialize_order_with_tasks(@production_order),
        'Production order updated successfully'
      )
    else
      render_error(
        'Failed to update production order',
        :unprocessable_content,
        @production_order.errors.full_messages
      )
    end
  end

  # DELETE /api/v1/production_orders/:id
  def destroy
    authorize @production_order

    if @production_order.destroy
      render_success(nil, 'Production order deleted successfully')
    else
      render_error('Failed to delete production order')
    end
  end

  # GET /api/v1/production_orders/:id/tasks_summary
  def tasks_summary
    authorize @production_order, :tasks_summary?

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

  # GET /api/v1/production_orders/monthly_statistics
  def monthly_statistics
    authorize ProductionOrder, :monthly_statistics?

    current_month_start = Date.current.beginning_of_month
    current_month_end = Date.current.end_of_month

    # Get orders accessible to current user
    base_orders = policy_scope(ProductionOrder)
    
    stats = {
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
    
    render_success(stats)
  end

  # GET /api/v1/production_orders/urgent_orders_report
  def urgent_orders_report
    authorize ProductionOrder, :urgent_orders_report?

    # Complex query for urgent orders with task statistics
    urgent_orders_with_stats = policy_scope(ProductionOrder)
      .joins("LEFT JOIN tasks ON tasks.production_order_id = production_orders.id")
      .where(type: 'UrgentOrder')
      .select(
        "production_orders.*",
        "MAX(CASE WHEN tasks.status = #{Task.statuses[:pending]} THEN tasks.expected_end_date END) as latest_pending_task_date",
        "COUNT(CASE WHEN tasks.status = #{Task.statuses[:pending]} THEN 1 END) as pending_tasks_count",
        "COUNT(CASE WHEN tasks.status = #{Task.statuses[:completed]} THEN 1 END) as completed_tasks_count",
        "COUNT(tasks.id) as total_tasks_count",
        "CASE 
          WHEN COUNT(tasks.id) > 0 
          THEN ROUND(COUNT(CASE WHEN tasks.status = #{Task.statuses[:completed]} THEN 1 END) * 100.0 / COUNT(tasks.id), 2)
          ELSE 0 
         END as completion_percentage"
      )
      .group("production_orders.id")
      .includes(:creator, :assigned_users)

    paginated_orders = paginate_collection(urgent_orders_with_stats)
    
    serialized_orders = paginated_orders.map do |order|
      serialize_order(order).merge({
        latest_pending_task_date: order.latest_pending_task_date,
        pending_tasks_count: order.pending_tasks_count.to_i,
        completed_tasks_count: order.completed_tasks_count.to_i,
        total_tasks_count: order.total_tasks_count.to_i,
        completion_percentage: order.completion_percentage.to_f
      })
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
    authorize ProductionOrder, :urgent_with_expired_tasks?

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
    permitted_params << :deadline if @order_type == 'UrgentOrder' || params[:production_order][:type] == 'UrgentOrder'
    
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
    orders.map { |order| serialize_order(order) }
  end

  def serialize_order(order)
    {
      id: order.id,
      order_number: order.order_number,
      type: order.type,
      start_date: order.start_date,
      expected_end_date: order.expected_end_date,
      deadline: order.try(:deadline),
      status: order.status,
      created_at: order.created_at,
      updated_at: order.updated_at,
      creator: {
        id: order.creator.id,
        name: order.creator.name,
        email: order.creator.email
      },
      assigned_users: order.assigned_users.map do |user|
        {
          id: user.id,
          name: user.name,
          email: user.email,
          role: user.role
        }
      end
    }
  end

  def serialize_order_with_tasks(order)
    serialize_order(order).merge({
      tasks: order.tasks.map { |task| serialize_task(task) },
      tasks_summary: {
        total: order.tasks.count,
        pending: order.tasks.pending.count,
        completed: order.tasks.completed.count,
        completion_percentage: calculate_completion_percentage(order)
      }
    })
  end

  def serialize_task(task)
    {
      id: task.id,
      description: task.description,
      expected_end_date: task.expected_end_date,
      status: task.status,
      is_overdue: task.expected_end_date < Date.current && task.pending?,
      created_at: task.created_at,
      updated_at: task.updated_at
    }
  end

  def calculate_completion_percentage(order)
    return 0 if order.tasks.count.zero?

    (order.tasks.completed.count.to_f / order.tasks.count * 100).round(2)
  end
end