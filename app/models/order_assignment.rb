class OrderAssignment < ApplicationRecord
  belongs_to :user
  belongs_to :production_order

  validates :user_id, uniqueness: {scope: :production_order_id, message: "User is already assigned to this order"}
end
