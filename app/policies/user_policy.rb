# frozen_string_literal: true

class UserPolicy < ApplicationPolicy
  # Scope: which users can be seen
  class Scope < Scope
    def resolve
      # Everyone can see all users
      scope.all
    end
  end

  def index?
    # Everyone can list users
    user.present?
  end

  def show?
    # Everyone can view any user
    user.present?
  end

  def create?
    # Only admin can create users
    admin?
  end

  def update?
    # Admin can update any user
    # Production_manager and operator can update their own profile
    admin? || record.id == user.id
  end

  def destroy?
    # Only admin can delete users
    # And cannot delete themselves (already validated in controller)
    admin?
  end

  # Permitted attributes for mass assignment
  def permitted_attributes_for_create
    # Only admin can create users, so they get all fields
    [:name, :email, :password, :password_confirmation, :role]
  end

  def permitted_attributes_for_update
    if admin?
      # Admin can update all fields
      [:name, :email, :password, :password_confirmation, :role]
    else
      # Non-admin can only update their own profile (limited fields)
      [:name, :email, :password, :password_confirmation]
    end
  end

  private

  def admin?
    user.role == 'admin'
  end
end
