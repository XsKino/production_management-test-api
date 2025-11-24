class ProductionOrder < ApplicationRecord
  belongs_to :creator, class_name: 'User'
  
  has_many :order_assignments, dependent: :destroy
  has_many :assigned_users, through: :order_assignments, source: :user
  
  has_many :tasks, dependent: :destroy
  
  accepts_nested_attributes_for :tasks, allow_destroy: true
  
  enum :status, { pending: 0, completed: 1, cancelled: 2 }
  
  validates :start_date, presence: true
  validates :expected_end_date, presence: true
  validates :status, presence: true
  validates :order_number, presence: true, uniqueness: { scope: :type }
  
  before_validation :set_order_number, on: :create
  
  # Helper: User has access to this order?
  def accessible_by?(user)
    return true if user.admin?
    creator_id == user.id || assigned_users.include?(user)
  end

  # Ransack: Define searchable attributes
  def self.ransackable_attributes(auth_object = nil)
    ["created_at", "creator_id", "deadline", "expected_end_date", "id", "order_number", "start_date", "status", "type", "updated_at"]
  end

  # Ransack: Define searchable associations
  def self.ransackable_associations(auth_object = nil)
    ["assigned_users", "creator", "order_assignments", "tasks"]
  end

  private
  
  # Autoincremental index based on 'type'
  def set_order_number
    return if order_number.present?
    
    last_order = self.class.base_class
                          .where(type: self.class.name)
                          .order(order_number: :desc)
                          .first
    
    self.order_number = (last_order&.order_number || 0) + 1
  end
end