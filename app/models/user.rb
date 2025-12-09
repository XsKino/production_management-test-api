class User < ApplicationRecord
  has_secure_password
  
  enum :role, { operator: 0, production_manager: 1, admin: 2 }
  
  has_many :created_orders, class_name: 'ProductionOrder', foreign_key: 'creator_id', dependent: :destroy
  
  has_many :order_assignments, dependent: :destroy
  has_many :assigned_orders, through: :order_assignments, source: :production_order
  
  validates :email, presence: true, uniqueness: true
  validates :name, presence: true
  validates :role, presence: true

  # Returns statistics about orders in a single query
  def order_statistics
    {
      created_orders_count: created_orders.count,
      assigned_orders_count: assigned_orders.count,
      pending_orders_count: assigned_orders.where(status: :pending).count,
      completed_orders_count: assigned_orders.where(status: :completed).count
    }
  end

  # Ransack: Define searchable attributes
  def self.ransackable_attributes(auth_object = nil)
    ["created_at", "email", "id", "name", "role", "updated_at"]
  end

  # Ransack: Define searchable associations
  def self.ransackable_associations(auth_object = nil)
    ["assigned_orders", "created_orders", "order_assignments"]
  end
end