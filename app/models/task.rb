class Task < ApplicationRecord
  belongs_to :production_order
  
  enum :status, {pending: 0, completed: 1}

  validates :description, presence: true
  validates :expected_end_date, presence: true
  validates :status, presence: true
end
