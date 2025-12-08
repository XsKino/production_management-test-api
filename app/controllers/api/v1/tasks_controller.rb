class Api::V1::TasksController < Api::V1::ApplicationController
  before_action :set_production_order
  before_action :set_task, only: [:update, :destroy, :complete, :reopen]

  # POST /api/v1/production_orders/:production_order_id/tasks
  def create
    @task = @production_order.tasks.build(task_params)
    authorize @task

    @task.save!

    render_success(
      serialize_task(@task),
      'Task created successfully',
      :created
    )
  end

  # PATCH/PUT /api/v1/production_orders/:production_order_id/tasks/:id
  def update
    authorize @task

    @task.update!(task_params)

    render_success(
      serialize_task(@task),
      'Task updated successfully'
    )
  end

  # DELETE /api/v1/production_orders/:production_order_id/tasks/:id
  def destroy
    authorize @task

    @task.destroy!

    render_success(nil, 'Task deleted successfully')
  end

  # PATCH /api/v1/production_orders/:production_order_id/tasks/:id/complete
  def complete
    authorize @task, :complete?

    @task.update!(status: :completed)

    render_success(
      serialize_task(@task),
      'Task marked as completed'
    )
  end

  # PATCH /api/v1/production_orders/:production_order_id/tasks/:id/reopen
  def reopen
    authorize @task, :reopen?

    @task.update!(status: :pending)

    render_success(
      serialize_task(@task),
      'Task reopened'
    )
  end

  private

  def set_production_order
    @production_order = policy_scope(ProductionOrder).find(params[:production_order_id])
  end

  def set_task
    @task = @production_order.tasks.find(params[:id])
  end

  def task_params
    params.require(:task).permit(:description, :expected_end_date, :status)
  end

  def serialize_task(task)
    TaskSerializer.new(task).serializable_hash[:data][:attributes].merge({
      is_overdue: task.expected_end_date < Date.current && task.pending?
    })
  end
end