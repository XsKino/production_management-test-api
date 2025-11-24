# frozen_string_literal: true

class TaskPolicy < ApplicationPolicy
  # Scope: which tasks the user can see
  class Scope < Scope
    def resolve
      case user.role
      when 'admin'
        scope.all
      when 'production_manager', 'operator'
        # Tasks from orders where user is assigned OR created
        scope.joins(:production_order).left_joins(production_order: :order_assignments)
             .where('order_assignments.user_id = ? OR production_orders.creator_id = ?', user.id, user.id)
             .distinct
      else
        scope.none
      end
    end
  end

  def show?
    admin? || assigned_to_order? || created_order?
  end

  def create?
    # Admin can create tasks on any order
    # Production_manager can create tasks if assigned or created the order
    # Operator CANNOT create tasks
    admin? || (production_manager? && (assigned_to_order? || created_order?))
  end

  def update?
    # Admin can update any task
    # Production_manager can update tasks from orders they're assigned to or created
    # Operator CANNOT update (only change status with complete/reopen)
    admin? || (production_manager? && (assigned_to_order? || created_order?))
  end

  def destroy?
    # Admin can delete any task
    # Production_manager can delete tasks from orders they're assigned to or created
    # Operator CANNOT delete
    admin? || (production_manager? && (assigned_to_order? || created_order?))
  end

  def complete?
    # Admin, production_manager and operator can complete tasks
    # But only if they have access to the order
    admin? || assigned_to_order? || created_order?
  end

  def reopen?
    # Admin, production_manager and operator can reopen tasks
    # But only if they have access to the order
    admin? || assigned_to_order? || created_order?
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
    record.production_order.assigned_users.include?(user)
  end

  def created_order?
    record.production_order.creator_id == user.id
  end
end
