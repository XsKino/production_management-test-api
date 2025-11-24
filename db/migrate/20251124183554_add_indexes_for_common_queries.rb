class AddIndexesForCommonQueries < ActiveRecord::Migration[8.1]
  def change
    # Tasks indexes for performance optimization
    # Used in: expired tasks queries, task status filtering
    add_index :tasks, [:status, :expected_end_date],
              name: 'index_tasks_on_status_and_expected_end_date',
              if_not_exists: true

    # Used in: task summary queries grouped by production_order
    add_index :tasks, [:production_order_id, :status],
              name: 'index_tasks_on_production_order_and_status',
              if_not_exists: true

    # Production Orders indexes for performance optimization
    # Used in: monthly statistics, filtering by type and date range
    add_index :production_orders, [:type, :start_date],
              name: 'index_production_orders_on_type_and_start_date',
              if_not_exists: true

    # Used in: urgent orders report, deadline filtering
    add_index :production_orders, [:type, :deadline],
              name: 'index_production_orders_on_type_and_deadline',
              if_not_exists: true

    # Used in: completed orders in time period queries
    add_index :production_orders, [:status, :updated_at],
              name: 'index_production_orders_on_status_and_updated_at',
              if_not_exists: true

    # Used in: combined filtering by type and status
    add_index :production_orders, [:type, :status],
              name: 'index_production_orders_on_type_and_status',
              if_not_exists: true

    # Note: index_production_orders_on_creator_id already exists from base migration

    # Users indexes
    # Used in: filtering users by role
    add_index :users, :role,
              name: 'index_users_on_role',
              if_not_exists: true
  end
end
