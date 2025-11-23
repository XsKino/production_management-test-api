class User < ApplicationRecord
  has_secure_password
  
  enum :role, { operator: 0, production_manager: 1, admin: 2 }
  
  has_many :created_orders, class_name: 'ProductionOrder', foreign_key: 'creator_id', dependent: :destroy
  
  has_many :order_assignments, dependent: :destroy
  has_many :assigned_orders, through: :order_assignments, source: :production_order
  
  validates :email, presence: true, uniqueness: true
  validates :name, presence: true
  validates :role, presence: true
end