FactoryBot.define do
  factory :task do
    description { "MyText" }
    expected_end_date { "2025-11-23" }
    status { 1 }
    production_order { nil }
  end
end
