FactoryBot.define do
  factory :task do
    description { Faker::Lorem.sentence }
    expected_end_date { Date.today + 3.days }
    status { :pending }
    association :production_order
    
    trait :completed do
      status { :completed }
    end
    
    trait :expired do
      expected_end_date { Date.yesterday }
    end
  end
end