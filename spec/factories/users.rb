FactoryBot.define do
  factory :user do
    email { Faker::Internet.unique.email }
    password { 'password123' }
    name { Faker::Name.name }
    role { :operator }
    
    trait :admin do
      role { :admin }
    end
    
    trait :production_manager do
      role { :production_manager }
    end
    
    trait :operator do
      role { :operator }
    end
  end
end