class CreateOrderAuditLogs < ActiveRecord::Migration[8.1]
  def change
    create_table :order_audit_logs do |t|
      t.references :production_order, null: true, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.string :action, null: false
      t.text :change_details
      t.string :ip_address
      t.string :user_agent

      t.timestamps
    end

    add_index :order_audit_logs, [:production_order_id, :created_at]
    add_index :order_audit_logs, :action
  end
end
