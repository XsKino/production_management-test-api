FactoryBot.define do
  factory :production_order do
    type { "" }
    order_number { 1 }
    start_date { "2025-11-23" }
    expected_end_date { "2025-11-23" }
    status { 1 }
    deadline { "2025-11-23" }
    creator { nil }
  end
end
