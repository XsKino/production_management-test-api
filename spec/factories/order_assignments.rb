FactoryBot.define do
  factory :order_assignment do
    association :user
    association :production_order, factory: :normal_order
  end
end
