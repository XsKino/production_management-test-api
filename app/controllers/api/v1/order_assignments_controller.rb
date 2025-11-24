class Api::V1::OrderAssignmentsController < Api::V1::ApplicationController

  # POST /api/v1/order_assignments
  def create
    @assignment = OrderAssignment.new(assignment_params)
    
    # Verify user has permission to assign users to this order
    unless can_assign_to_order?(@assignment.production_order)
      return render_error('You are not authorized to assign users to this order', :forbidden)
    end

    if @assignment.save
      render_success(
        serialize_assignment(@assignment),
        'User assigned to order successfully',
        :created
      )
    else
      render_error(
        'Failed to assign user to order',
        :unprocessable_content,
        @assignment.errors.full_messages
      )
    end
  end

  # DELETE /api/v1/order_assignments/:id
  def destroy
    @assignment = OrderAssignment.find(params[:id])
    
    # Verify user has permission to remove assignments from this order
    unless can_assign_to_order?(@assignment.production_order)
      return render_error('You are not authorized to remove assignments from this order', :forbidden)
    end

    if @assignment.destroy
      render_success(nil, 'User removed from order successfully')
    else
      render_error('Failed to remove user from order')
    end
  end

  private

  def assignment_params
    params.require(:order_assignment).permit(:user_id, :production_order_id)
  end

  def can_assign_to_order?(production_order)
    # TODO: Replace with Pundit policy
    # For now, basic authorization logic
    case current_user.role
    when 'admin'
      true
    when 'production_manager'
      # Can assign if they created the order or are assigned to it
      production_order.creator_id == current_user.id || 
      production_order.assigned_users.include?(current_user)
    else
      false
    end
  end

  def serialize_assignment(assignment)
    {
      id: assignment.id,
      user: {
        id: assignment.user.id,
        name: assignment.user.name,
        email: assignment.user.email,
        role: assignment.user.role
      },
      production_order: {
        id: assignment.production_order.id,
        order_number: assignment.production_order.order_number,
        type: assignment.production_order.type
      },
      created_at: assignment.created_at
    }
  end
end