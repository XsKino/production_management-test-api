class CreateProductionOrders < ActiveRecord::Migration[8.1]
  def change
    create_table :production_orders do |t|
      t.string :type, null: false
      t.integer :order_number, null: false
      t.date :start_date, null: false
      t.date :expected_end_date, null: false
      t.integer :status, null: false, default: 0
      t.date :deadline, null: true
      t.references :creator, null: false, foreign_key: {to_table: :users}

      t.timestamps
    end

    add_index :production_orders, [:type, :order_number], unique: true

  end
end
