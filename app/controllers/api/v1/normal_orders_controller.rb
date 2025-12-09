class Api::V1::NormalOrdersController < Api::V1::ProductionOrdersController
  private

  # Override to always return NormalOrder class
  def order_class
    NormalOrder
  end
end
