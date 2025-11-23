require 'rails_helper'

RSpec.describe NormalOrder, type: :model do
  describe 'inheritance' do
    it 'inherits from ProductionOrder' do
      expect(NormalOrder.superclass).to eq(ProductionOrder)
    end

    it 'has correct STI type' do
      order = create(:normal_order)
      expect(order.type).to eq('NormalOrder')
    end
  end

  describe 'validations' do
    it 'inherits all ProductionOrder validations' do
      order = build(:normal_order, start_date: nil)
      expect(order).not_to be_valid
      expect(order.errors[:start_date]).to include("can't be blank")
    end

    it 'does not require deadline field' do
      order = build(:normal_order, deadline: nil)
      expect(order).to be_valid
    end
  end

  describe 'order numbering' do
    it 'maintains separate counter from UrgentOrder' do
      urgent = create(:urgent_order)
      normal = create(:normal_order)
      
      expect(urgent.order_number).to eq(1)
      expect(normal.order_number).to eq(1)
    end

    it 'increments within its own type' do
      normal1 = create(:normal_order)
      normal2 = create(:normal_order)
      
      expect(normal1.order_number).to eq(1)
      expect(normal2.order_number).to eq(2)
    end
  end

  describe 'factory' do
    it 'creates valid normal order' do
      order = build(:normal_order)
      expect(order).to be_valid
    end
  end
end