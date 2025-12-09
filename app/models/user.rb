class User < ApplicationRecord
  has_secure_password
  
  enum :role, { operator: 0, production_manager: 1, admin: 2 }
  
  has_many :created_orders, class_name: 'ProductionOrder', foreign_key: 'creator_id', dependent: :destroy
  
  has_many :order_assignments, dependent: :destroy
  has_many :assigned_orders, through: :order_assignments, source: :production_order
  
  validates :email, presence: true, uniqueness: true
  validates :name, presence: true
  validates :role, presence: true

  # Scope: Search users by name or email (case-insensitive)
  scope :search_by_name_or_email, ->(term) {
    where('name ILIKE ? OR email ILIKE ?', "%#{term}%", "%#{term}%") if term.present?
  }

  # Returns statistics about orders in a single aggregated query
  # More efficient than making 4 separate queries
  def order_statistics
    # Get counts for created orders
    created_count = created_orders.count

    # Get all assigned order statistics in a single query
    assigned_stats = assigned_orders
      .group(:status)
      .count

    {
      created_orders_count: created_count,
      assigned_orders_count: assigned_stats.values.sum,
      pending_orders_count: assigned_stats['pending'] || 0,
      completed_orders_count: assigned_stats['completed'] || 0
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