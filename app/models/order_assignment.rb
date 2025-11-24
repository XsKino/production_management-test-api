class OrderAssignment < ApplicationRecord
  belongs_to :user
  belongs_to :production_order

  validates :user_id, uniqueness: {scope: :production_order_id, message: "User is already assigned to this order"}

  # Ransack: Define searchable attributes
  def self.ransackable_attributes(auth_object = nil)
    ["created_at", "id", "production_order_id", "updated_at", "user_id"]
  end

  # Ransack: Define searchable associations
  def self.ransackable_associations(auth_object = nil)
    ["production_order", "user"]
  end
end
