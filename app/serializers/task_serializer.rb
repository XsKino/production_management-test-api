# frozen_string_literal: true

class TaskSerializer
  include FastJsonapi::ObjectSerializer

  attributes :id, :description, :expected_end_date, :status, :created_at, :updated_at

  # Include the production_order_id
  attribute :production_order_id

  # Optionally include the full order details
  belongs_to :production_order, serializer: :production_order
end
