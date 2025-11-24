require 'rails_helper'

RSpec.describe ProductionOrder, type: :model do
  describe 'associations' do
    it { should belong_to(:creator).class_name('User') }
    it { should have_many(:order_assignments).dependent(:destroy) }
    it { should have_many(:assigned_users).through(:order_assignments).source(:user) }
    it { should have_many(:tasks).dependent(:destroy) }
  end

  describe 'validations' do
    subject { build(:normal_order) }

    it { should validate_presence_of(:start_date) }
    it { should validate_presence_of(:expected_end_date) }
    it { should validate_presence_of(:status) }

    context 'date validations' do
      let(:creator) { create(:user) }

      it 'is valid when expected_end_date equals start_date' do
        order = build(:normal_order, creator: creator, start_date: Date.current, expected_end_date: Date.current)
        expect(order).to be_valid
      end

      it 'is valid when expected_end_date is after start_date' do
        order = build(:normal_order, creator: creator, start_date: Date.current, expected_end_date: 1.week.from_now)
        expect(order).to be_valid
      end

      it 'is invalid when expected_end_date is before start_date' do
        order = build(:normal_order, creator: creator, start_date: Date.current, expected_end_date: 1.week.ago)
        expect(order).not_to be_valid
        expect(order.errors[:expected_end_date]).to include('must be greater than or equal to start date')
      end
    end
  end

  describe 'enums' do
    it { should define_enum_for(:status).with_values(pending: 0, completed: 1, cancelled: 2) }
  end

  describe 'nested attributes' do
    it { should accept_nested_attributes_for(:tasks).allow_destroy(true) }
  end

  describe 'order number generation' do
    let(:creator) { create(:user) }

    context 'for NormalOrder' do
      it 'starts numbering from 1' do
        order = create(:normal_order, creator: creator)
        expect(order.order_number).to eq(1)
      end

      it 'increments order number for same type' do
        create(:normal_order, creator: creator)
        order2 = create(:normal_order, creator: creator)
        expect(order2.order_number).to eq(2)
      end

      it 'maintains separate numbering from UrgentOrder' do
        create(:urgent_order, creator: creator)
        normal_order = create(:normal_order, creator: creator)
        expect(normal_order.order_number).to eq(1)
      end
    end

    context 'for UrgentOrder' do
      it 'starts numbering from 1' do
        order = create(:urgent_order, creator: creator)
        expect(order.order_number).to eq(1)
      end

      it 'increments order number for same type' do
        create(:urgent_order, creator: creator)
        order2 = create(:urgent_order, creator: creator)
        expect(order2.order_number).to eq(2)
      end

      it 'maintains separate numbering from NormalOrder' do
        create(:normal_order, creator: creator)
        urgent_order = create(:urgent_order, creator: creator)
        expect(urgent_order.order_number).to eq(1)
      end
    end

    it 'validates uniqueness of order_number scoped to type' do
      order1 = create(:normal_order, creator: creator)
      order2 = build(:normal_order, creator: creator, order_number: order1.order_number)
      
      expect(order2).not_to be_valid
      expect(order2.errors[:order_number]).to include('has already been taken')
    end

    it 'allows same order_number for different types' do
      normal_order = create(:normal_order, creator: creator)
      urgent_order = build(:urgent_order, creator: creator, order_number: normal_order.order_number)
      
      expect(urgent_order).to be_valid
    end
  end

  describe '#accessible_by?' do
    let(:admin) { create(:user, role: :admin) }
    let(:manager) { create(:user, role: :production_manager) }
    let(:operator) { create(:user, role: :operator) }
    let(:creator) { create(:user, role: :production_manager) }
    let(:order) { create(:normal_order, creator: creator) }

    context 'when user is admin' do
      it 'returns true for any order' do
        expect(order.accessible_by?(admin)).to be true
      end
    end

    context 'when user is creator' do
      it 'returns true' do
        expect(order.accessible_by?(creator)).to be true
      end
    end

    context 'when user is assigned to order' do
      before do
        create(:order_assignment, user: operator, production_order: order)
      end

      it 'returns true' do
        expect(order.accessible_by?(operator)).to be true
      end
    end

    context 'when user has no access to order' do
      it 'returns false' do
        expect(order.accessible_by?(manager)).to be false
      end
    end
  end

  describe 'dependent destroy' do
    let(:order) { create(:normal_order) }
    
    it 'destroys associated order_assignments when order is destroyed' do
      assignment = create(:order_assignment, production_order: order)
      
      expect { order.destroy }.to change(OrderAssignment, :count).by(-1)
    end

    it 'destroys associated tasks when order is destroyed' do
      task = create(:task, production_order: order)
      
      expect { order.destroy }.to change(Task, :count).by(-1)
    end
  end

  describe 'nested attributes creation' do
    let(:creator) { create(:user) }
    
    it 'creates order with tasks using nested attributes' do
      order_params = {
        creator: creator,
        start_date: Date.current,
        expected_end_date: 1.week.from_now,
        status: :pending,
        tasks_attributes: [
          {
            description: 'Task 1',
            expected_end_date: 2.days.from_now,
            status: :pending
          },
          {
            description: 'Task 2',
            expected_end_date: 3.days.from_now,
            status: :pending
          }
        ]
      }

      order = NormalOrder.create!(order_params)
      
      expect(order.tasks.count).to eq(2)
      expect(order.tasks.first.description).to eq('Task 1')
      expect(order.tasks.second.description).to eq('Task 2')
    end
  end
end