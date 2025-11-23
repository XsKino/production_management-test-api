class CreateTasks < ActiveRecord::Migration[8.1]
  def change
    create_table :tasks do |t|
      t.text :description, null: false
      t.date :expected_end_date, null: false
      t.integer :status, null: false, default: 0
      t.references :production_order, null: false, foreign_key: true

      t.timestamps
    end
  end
end
