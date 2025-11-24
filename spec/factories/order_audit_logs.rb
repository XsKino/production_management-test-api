FactoryBot.define do
  factory :order_audit_log do
    association :production_order, factory: :normal_order
    association :user
    action { "created" }
    change_details { { order_number: 1, status: "pending" } }
    ip_address { "127.0.0.1" }
    user_agent { "Mozilla/5.0" }
  end
end
