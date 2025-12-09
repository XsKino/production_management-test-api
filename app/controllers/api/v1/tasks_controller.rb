class Api::V1::TasksController < Api::V1::ApplicationController
  before_action :set_production_order
  before_action :set_task, only: [:update, :destroy, :complete, :reopen]

  # This callback uses the generic authorize_resource from ApplicationController
  # Excluding 'create' because it needs manual authorization with @production_order context
  before_action :authorize_resource, except: [:create]

  # POST /api/v1/production_orders/:production_order_id/tasks
  def create
    # Build temporary task to get permitted attributes
    temp_task = @production_order.tasks.build
    permitted_attrs = policy(temp_task).permitted_attributes_for_create

    @task = @production_order.tasks.build(params.require(:task).permit(permitted_attrs))

    # Manual authorization: TaskPolicy#create? may need @production_order context
    authorize @task

    @task.save!

    render_success(
      serialize(@task, merge: { is_overdue: @task.expected_end_date < Date.current && @task.pending? }),
      'Task created successfully',
      :created
    )
  end

  # PATCH/PUT /api/v1/production_orders/:production_order_id/tasks/:id
  def update
    permitted_attrs = policy(@task).permitted_attributes_for_update
    @task.update!(params.require(:task).permit(permitted_attrs))

    render_success(
      serialize(@task, merge: { is_overdue: @task.expected_end_date < Date.current && @task.pending? }),
      'Task updated successfully'
    )
  end

  # DELETE /api/v1/production_orders/:production_order_id/tasks/:id
  def destroy
    @task.destroy!

    render_success(nil, 'Task deleted successfully')
  end

  # PATCH /api/v1/production_orders/:production_order_id/tasks/:id/complete
  def complete
    @task.update!(status: :completed)

    render_success(
      serialize(@task, merge: { is_overdue: @task.expected_end_date < Date.current && @task.pending? }),
      'Task marked as completed'
    )
  end

  # PATCH /api/v1/production_orders/:production_order_id/tasks/:id/reopen
  def reopen
    @task.update!(status: :pending)

    render_success(
      serialize(@task, merge: { is_overdue: @task.expected_end_date < Date.current && @task.pending? }),
      'Task reopened'
    )
  end

  private

  def set_production_order
    @production_order = policy_scope(ProductionOrder).find(params[:production_order_id])
  end

  def set_task
    # Clean: only fetches the record
    @task = @production_order.tasks.find(params[:id])
  end
end