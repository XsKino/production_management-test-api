class Task < ApplicationRecord
  belongs_to :production_order
  
  enum :status, {pending: 0, completed: 1}

  validates :description, presence: true
  validates :expected_end_date, presence: true
  validates :status, presence: true

  # Ransack: Define searchable attributes
  def self.ransackable_attributes(auth_object = nil)
    ["created_at", "description", "expected_end_date", "id", "production_order_id", "status", "updated_at"]
  end

  # Ransack: Define searchable associations
  def self.ransackable_associations(auth_object = nil)
    ["production_order"]
  end
end
