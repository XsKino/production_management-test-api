FactoryBot.define do
  factory :production_order do
    start_date { Date.today }
    expected_end_date { Date.today + 5.days }
    status { :pending }
    association :creator, factory: :user
    
    factory :normal_order, class: 'NormalOrder'
    
    factory :urgent_order, class: 'UrgentOrder' do
      deadline { Date.today + 7.days }
    end
  end
end
