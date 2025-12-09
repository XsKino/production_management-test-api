# frozen_string_literal: true

class ProductionOrderPolicy < ApplicationPolicy
  # Scope: which orders the user can see
  class Scope < Scope
    def resolve
      case user.role
      when 'admin'
        scope.all
      when 'production_manager', 'operator'
        # Orders where user is assigned OR orders they created
        scope.left_joins(:order_assignments)
             .where('order_assignments.user_id = ? OR production_orders.creator_id = ?', user.id, user.id)
             .distinct
      else
        scope.none
      end
    end
  end

  def index?
    # All roles can list orders (with scope applied)
    user.present?
  end

  def show?
    admin? || assigned_to_order? || created_order?
  end

  def create?
    # Only admin and production_manager can create orders
    admin? || production_manager?
  end

  def update?
    # Admin can update any order
    # Production_manager can update if assigned or created the order
    admin? || (production_manager? && (assigned_to_order? || created_order?))
  end

  def destroy?
    # Only admin or creator (if production_manager) can delete
    admin? || (production_manager? && created_order?)
  end

  def tasks_summary?
    show?
  end

  def monthly_statistics?
    # All users can view statistics
    user.present?
  end

  def urgent_orders_report?
    # All users can view this report
    user.present?
  end

  def urgent_with_expired_tasks?
    # All users can view this report
    user.present?
  end

  # Permitted attributes for mass assignment
  # Pundit allows different attributes based on the action
  def permitted_attributes_for_create
    base_attrs = [:start_date, :expected_end_date, :status,
                 tasks_attributes: [:id, :description, :expected_end_date, :status, :_destroy]]

    # Add deadline for UrgentOrder
    base_attrs << :deadline if record.is_a?(UrgentOrder)

    base_attrs
  end

  def permitted_attributes_for_update
    permitted_attributes_for_create
  end

  private

  def admin?
    user.role == 'admin'
  end

  def production_manager?
    user.role == 'production_manager'
  end

  def operator?
    user.role == 'operator'
  end

  def assigned_to_order?
    record.assigned_users.include?(user)
  end

  def created_order?
    record.creator_id == user.id
  end
end
