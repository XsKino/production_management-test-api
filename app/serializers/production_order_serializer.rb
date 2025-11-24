# frozen_string_literal: true

class ProductionOrderSerializer
  include FastJsonapi::ObjectSerializer

  attributes :id, :type, :order_number, :start_date, :expected_end_date, :status, :created_at, :updated_at

  # Include deadline for UrgentOrder
  attribute :deadline, if: Proc.new { |record| record.is_a?(UrgentOrder) }

  # Include relationships
  belongs_to :creator, serializer: :user
  has_many :tasks, serializer: :task
  has_many :assigned_users, serializer: :user

  # Add computed attributes
  attribute :tasks_count do |order|
    order.tasks.count
  end

  attribute :completed_tasks_count do |order|
    order.tasks.where(status: :completed).count
  end

  attribute :is_urgent do |order|
    order.is_a?(UrgentOrder)
  end
end
