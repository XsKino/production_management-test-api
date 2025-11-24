# frozen_string_literal: true

class UrgentOrderSerializer < ProductionOrderSerializer
  # Inherits all attributes from ProductionOrderSerializer
  # Deadline is automatically included via conditional in parent

  # Add days until deadline
  attribute :days_until_deadline do |order|
    next nil unless order.deadline
    (order.deadline - Date.current).to_i
  end
end
