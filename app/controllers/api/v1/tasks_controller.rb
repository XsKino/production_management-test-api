class Api::V1::TasksController < Api::V1::ApplicationController
  before_action :set_production_order
  before_action :set_task, only: [:update, :destroy, :complete, :reopen]

  # POST /api/v1/production_orders/:production_order_id/tasks
  def create
    @task = @production_order.tasks.build(task_params)

    if @task.save
      render_success(
        serialize_task(@task),
        'Task created successfully',
        :created
      )
    else
      render_error(
        'Failed to create task',
        :unprocessable_content,
        @task.errors.full_messages
      )
    end
  end

  # PATCH/PUT /api/v1/production_orders/:production_order_id/tasks/:id
  def update
    if @task.update(task_params)
      render_success(
        serialize_task(@task),
        'Task updated successfully'
      )
    else
      render_error(
        'Failed to update task',
        :unprocessable_content,
        @task.errors.full_messages
      )
    end
  end

  # DELETE /api/v1/production_orders/:production_order_id/tasks/:id
  def destroy
    if @task.destroy
      render_success(nil, 'Task deleted successfully')
    else
      render_error('Failed to delete task')
    end
  end

  # PATCH /api/v1/production_orders/:production_order_id/tasks/:id/complete
  def complete
    if @task.update(status: :completed)
      render_success(
        serialize_task(@task),
        'Task marked as completed'
      )
    else
      render_error(
        'Failed to complete task',
        :unprocessable_content,
        @task.errors.full_messages
      )
    end
  end

  # PATCH /api/v1/production_orders/:production_order_id/tasks/:id/reopen  
  def reopen
    if @task.update(status: :pending)
      render_success(
        serialize_task(@task),
        'Task reopened'
      )
    else
      render_error(
        'Failed to reopen task',
        :unprocessable_content,
        @task.errors.full_messages
      )
    end
  end

  private

  def set_production_order
    # TODO: Apply Pundit authorization here
    @production_order = authorized_orders.find(params[:production_order_id])
  end

  def set_task
    @task = @production_order.tasks.find(params[:id])
  end

  def authorized_orders
    # TODO: Replace with Pundit policy scopes
    # For now, basic authorization based on user role
    case current_user.role
    when 'admin'
      ProductionOrder.all
    when 'production_manager', 'operator'
      ProductionOrder.joins(:order_assignments)
                    .where(order_assignments: { user_id: current_user.id })
                    .or(ProductionOrder.where(creator_id: current_user.id))
    else
      ProductionOrder.none
    end
  end

  def task_params
    params.require(:task).permit(:description, :expected_end_date, :status)
  end

  def serialize_task(task)
    {
      id: task.id,
      description: task.description,
      expected_end_date: task.expected_end_date,
      status: task.status,
      is_overdue: task.expected_end_date < Date.current && task.pending?,
      production_order_id: task.production_order_id,
      created_at: task.created_at,
      updated_at: task.updated_at
    }
  end
end