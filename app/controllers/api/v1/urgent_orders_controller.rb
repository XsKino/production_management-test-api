class Api::V1::UrgentOrdersController < Api::V1::ProductionOrdersController
  private

  # Override to always return UrgentOrder class
  def order_class
    UrgentOrder
  end
end
