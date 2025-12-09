class ProductionOrder < ApplicationRecord
  include Auditable

  belongs_to :creator, class_name: 'User'
  
  has_many :order_assignments, dependent: :destroy
  has_many :assigned_users, through: :order_assignments, source: :user
  
  has_many :tasks, dependent: :destroy
  has_many :audit_logs, class_name: 'OrderAuditLog', dependent: :nullify

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

  # Returns a hash with task statistics and summary
  # Uses database queries for accuracy, but optimizes by using loaded associations when available
  def tasks_summary
    # Use loaded tasks if available to avoid extra queries, otherwise query database
    if tasks.loaded?
      task_list = tasks.to_a
      pending_count = task_list.count(&:pending?)
      completed_count = task_list.count(&:completed?)
      overdue_count = task_list.count { |t| t.expected_end_date < Date.current && t.pending? }
    else
      pending_count = tasks.pending.count
      completed_count = tasks.completed.count
      overdue_count = tasks.where('expected_end_date < ? AND status = ?', Date.current, Task.statuses[:pending]).count
    end

    {
      total: tasks.loaded? ? tasks.size : tasks.count,
      pending: pending_count,
      completed: completed_count,
      completion_percentage: calculate_completion_percentage,
      overdue: overdue_count
    }
  end

  # Assign users to this order
  def assign_users!(user_ids)
    return if user_ids.blank?

    user_ids = user_ids.compact.uniq
    user_ids.each do |user_id|
      order_assignments.find_or_create_by(user_id: user_id)
    end
  end

  # Update user assignments (replaces existing assignments)
  def update_assignments!(user_ids)
    return if user_ids.blank?

    order_assignments.destroy_all
    assign_users!(user_ids)
  end

  # Ransack: Define searchable attributes
  def self.ransackable_attributes(auth_object = nil)
    ["created_at", "creator_id", "deadline", "expected_end_date", "id", "order_number", "start_date", "status", "type", "updated_at"]
  end

  # Ransack: Define searchable associations
  def self.ransackable_associations(auth_object = nil)
    ["assigned_users", "creator", "order_assignments", "tasks"]
  end

  # Class method: Get monthly statistics for a given user and date range
  # @param user [User] The user for policy scoping
  # @param month_start [Date] Start of the month
  # @param month_end [Date] End of the month
  # @param base_scope [ActiveRecord::Relation] Pre-filtered scope (e.g., from policy_scope)
  # @return [Hash] Statistics for the current month
  def self.monthly_statistics_for(base_scope, month_start, month_end)
    {
      current_month: {
        normal_orders_starting: base_scope.where(type: 'NormalOrder')
                                          .where(start_date: month_start..month_end)
                                          .count,
        urgent_orders_with_deadline: base_scope.where(type: 'UrgentOrder')
                                               .where(deadline: month_start..month_end)
                                               .count,
        total_orders_started: base_scope.where(start_date: month_start..month_end).count,
        completed_orders: base_scope.where(status: :completed)
                                   .where(updated_at: month_start..month_end)
                                   .count
      }
    }
  end

  # Class method: Get urgent orders with detailed report including task statistics
  # Uses lateral join to fetch latest pending task and aggregated statistics
  # @param base_scope [ActiveRecord::Relation] Pre-filtered scope (e.g., from policy_scope)
  # @return [ActiveRecord::Relation] Urgent orders with task statistics
  def self.urgent_orders_with_report(base_scope)
    # Store statuses in variables for clean interpolation
    pending_status = Task.statuses[:pending]
    completed_status = Task.statuses[:completed]

    # Define Lateral Join
    # Fetches the latest pending task specific to the current order
    lateral_join_sql = <<~SQL
      LEFT JOIN LATERAL (
        SELECT
          id,
          description,
          expected_end_date,
          status,
          created_at,
          updated_at
        FROM tasks
        WHERE tasks.production_order_id = production_orders.id
          AND tasks.status = #{pending_status}
        ORDER BY id DESC
        LIMIT 1
      ) AS latest_task ON true
    SQL

    # Build the Query
    base_scope
      .joins("LEFT JOIN tasks ON tasks.production_order_id = production_orders.id") # Join 1: To count global statistics
      .joins(lateral_join_sql) # Join 2: To fetch specific fields of the latest task
      .where(type: 'UrgentOrder')
      .select(
        "production_orders.*",

        # Latest pending task fields (use ANY_VALUE to avoid GROUP BY errors)
        "ANY_VALUE(latest_task.id) as latest_pending_task_id",
        "ANY_VALUE(latest_task.description) as latest_pending_task_description",
        "ANY_VALUE(latest_task.expected_end_date) as latest_pending_task_expected_end_date",
        "ANY_VALUE(latest_task.status) as latest_pending_task_status",
        "ANY_VALUE(latest_task.created_at) as latest_pending_task_created_at",
        "ANY_VALUE(latest_task.updated_at) as latest_pending_task_updated_at",

        # Aggregated Statistics (using 'tasks' table from first join)
        "COUNT(CASE WHEN tasks.status = #{pending_status} THEN 1 END) as pending_tasks_count",
        "COUNT(CASE WHEN tasks.status = #{completed_status} THEN 1 END) as completed_tasks_count",
        "COUNT(tasks.id) as total_tasks_count",
        "CASE
           WHEN COUNT(tasks.id) > 0
           THEN ROUND(COUNT(CASE WHEN tasks.status = #{completed_status} THEN 1 END) * 100.0 / COUNT(tasks.id), 2)
           ELSE 0
         END as completion_percentage"
      )
      .group("production_orders.id")
      .includes(:creator, :assigned_users)
  end

  # Class method: Get urgent orders with at least one expired pending task
  # @param base_scope [ActiveRecord::Relation] Pre-filtered scope (e.g., from policy_scope)
  # @return [ActiveRecord::Relation] Urgent orders with expired tasks
  def self.urgent_with_expired_tasks(base_scope)
    base_scope
      .joins(:tasks)
      .where(type: 'UrgentOrder')
      .where(tasks: { 
        status: Task.statuses[:pending],
        expected_end_date: ...Date.current 
      })
      .distinct
      .includes(:creator, :assigned_users, :tasks)
  end

  private

  # Calculate completion percentage based on completed tasks
  # Uses loaded tasks if available to avoid extra queries
  def calculate_completion_percentage
    if tasks.loaded?
      total_tasks = tasks.size
      return 0 if total_tasks.zero?
      
      completed_tasks = tasks.count(&:completed?)
      (completed_tasks.to_f / total_tasks * 100).round(2)
    else
      total_tasks = tasks.count
      return 0 if total_tasks.zero?

      completed_tasks = tasks.completed.count
      (completed_tasks.to_f / total_tasks * 100).round(2)
    end
  end

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