class CreateOrderAssignments < ActiveRecord::Migration[8.1]
  def change
    create_table :order_assignments do |t|
      t.references :user, null: false, foreign_key: {to_table: :users}
      t.references :production_order, null: false, foreign_key: {to_table: :production_orders}

      t.timestamps
    end

    add_index :order_assignments, [:user_id, :production_order_id], unique: true
  end
end
