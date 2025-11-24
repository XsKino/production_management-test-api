require 'rails_helper'

RSpec.describe UrgentOrder, type: :model do
  describe 'inheritance' do
    it 'inherits from ProductionOrder' do
      expect(UrgentOrder.superclass).to eq(ProductionOrder)
    end

    it 'has correct STI type' do
      order = create(:urgent_order)
      expect(order.type).to eq('UrgentOrder')
    end
  end

  describe 'validations' do
    it 'inherits all ProductionOrder validations' do
      order = build(:urgent_order, start_date: nil)
      expect(order).not_to be_valid
      expect(order.errors[:start_date]).to include("can't be blank")
    end

    it 'requires deadline field' do
      order = build(:urgent_order, deadline: nil)
      expect(order).not_to be_valid
      expect(order.errors[:deadline]).to include("can't be blank")
    end

    it 'is valid with deadline' do
      order = build(:urgent_order, deadline: 1.week.from_now)
      expect(order).to be_valid
    end

    context 'deadline date validations' do
      let(:creator) { create(:user) }

      it 'is valid when deadline equals start_date' do
        order = build(:urgent_order, creator: creator, start_date: Date.current, deadline: Date.current)
        expect(order).to be_valid
      end

      it 'is valid when deadline is after start_date' do
        order = build(:urgent_order, creator: creator, start_date: Date.current, deadline: 1.week.from_now)
        expect(order).to be_valid
      end

      it 'is invalid when deadline is before start_date' do
        order = build(:urgent_order, creator: creator, start_date: Date.current, deadline: 1.week.ago)
        expect(order).not_to be_valid
        expect(order.errors[:deadline]).to include('must be greater than or equal to start date')
      end
    end
  end

  describe 'order numbering' do
    it 'maintains separate counter from NormalOrder' do
      normal = create(:normal_order)
      urgent = create(:urgent_order)
      
      expect(normal.order_number).to eq(1)
      expect(urgent.order_number).to eq(1)
    end

    it 'increments within its own type' do
      urgent1 = create(:urgent_order)
      urgent2 = create(:urgent_order)
      
      expect(urgent1.order_number).to eq(1)
      expect(urgent2.order_number).to eq(2)
    end
  end

  describe 'deadline field' do
    it 'stores and retrieves deadline correctly' do
      deadline = 1.week.from_now.to_date
      order = create(:urgent_order, deadline: deadline)

      expect(order.deadline).to eq(deadline)
    end
  end

  describe 'factory' do
    it 'creates valid urgent order' do
      order = build(:urgent_order)
      expect(order).to be_valid
    end
  end
end