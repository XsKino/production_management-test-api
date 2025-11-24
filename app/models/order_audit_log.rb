class OrderAuditLog < ApplicationRecord
  belongs_to :production_order, optional: true
  belongs_to :user

  validates :action, presence: true

  # Serialize change_details as JSON
  serialize :change_details, coder: JSON

  # Define available actions
  ACTIONS = %w[
    created
    updated
    deleted
    status_changed
    type_changed
    assigned
    unassigned
    task_added
    task_updated
    task_deleted
  ].freeze

  validates :action, inclusion: { in: ACTIONS }

  # Scopes
  scope :recent, -> { order(created_at: :desc) }
  scope :for_order, ->(order_id) { where(production_order_id: order_id) }
  scope :by_user, ->(user_id) { where(user_id: user_id) }
  scope :by_action, ->(action) { where(action: action) }

  # Ransack configuration
  def self.ransackable_attributes(auth_object = nil)
    ["action", "created_at", "id", "production_order_id", "updated_at", "user_id"]
  end

  def self.ransackable_associations(auth_object = nil)
    ["production_order", "user"]
  end
end
