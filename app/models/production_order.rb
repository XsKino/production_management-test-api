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

  validate :expected_end_date_after_start_date

  before_validation :set_order_number, on: :create
  before_validation :recalculate_order_number_on_type_change, on: :update
  
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

  # Validate that expected_end_date is not before start_date
  def expected_end_date_after_start_date
    return unless expected_end_date.present? && start_date.present?

    if expected_end_date < start_date
      errors.add(:expected_end_date, "must be greater than or equal to start date")
    end
  end

  # Autoincremental index based on 'type'
  def set_order_number
    return if order_number.present?

    last_order = self.class.base_class
                          .where(type: self.class.name)
                          .order(order_number: :desc)
                          .first

    self.order_number = (last_order&.order_number || 0) + 1
  end

  # Recalculate order_number when type changes
  def recalculate_order_number_on_type_change
    return unless type_changed?
    # Don't recalculate if order_number was explicitly changed by the user
    return if order_number_changed?

    # Get the next order_number for the new type
    # Use self.type (the new type) instead of self.class.name
    last_order = self.class.base_class
                          .where(type: self.type)
                          .where.not(id: self.id) # Exclude current record
                          .order(order_number: :desc)
                          .first

    self.order_number = (last_order&.order_number || 0) + 1
  end
end