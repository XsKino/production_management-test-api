require 'rails_helper'

RSpec.describe ProductionOrderPolicy, type: :policy do
  let(:admin) { create(:user, role: 'admin') }
  let(:production_manager) { create(:user, role: 'production_manager') }
  let(:operator) { create(:user, role: 'operator') }
  let(:other_operator) { create(:user, role: 'operator') }

  let!(:order_created_by_manager) { create(:normal_order, creator: production_manager) }
  let!(:order_with_assigned_operator) { create(:normal_order, creator: production_manager) }
  let!(:unrelated_order) { create(:normal_order, creator: admin) }

  before do
    create(:order_assignment, user: operator, production_order: order_with_assigned_operator)
  end

  describe 'Scope' do
    it 'allows admin to see all orders' do
      # Admin should see all 3 let! orders
      scope = Pundit.policy_scope(admin, ProductionOrder)
      expect(scope.count).to eq(3)
    end

    it 'allows production_manager to see orders they created' do
      # Production manager created 2 orders (order_created_by_manager and order_with_assigned_operator)
      scope = Pundit.policy_scope(production_manager, ProductionOrder)
      expect(scope.count).to eq(2)
    end

    it 'allows production_manager to see orders they are assigned to' do
      order = create(:normal_order, creator: admin)
      create(:order_assignment, user: production_manager, production_order: order)
      scope = Pundit.policy_scope(production_manager, ProductionOrder)
      # 2 created orders + 1 assigned order = 3
      expect(scope.count).to eq(3)
    end

    it 'allows operator to see orders they are assigned to' do
      # Operator is assigned to order_with_assigned_operator (1 order)
      scope = Pundit.policy_scope(operator, ProductionOrder)
      expect(scope.count).to eq(1)
    end
  end

  describe '#index?' do
    subject { described_class.new(user, ProductionOrder) }

    context 'as admin' do
      let(:user) { admin }
      it { is_expected.to permit_action(:index) }
    end

    context 'as production_manager' do
      let(:user) { production_manager }
      it { is_expected.to permit_action(:index) }
    end

    context 'as operator' do
      let(:user) { operator }
      it { is_expected.to permit_action(:index) }
    end
  end

  describe '#show?' do
    context 'as admin viewing any order' do
      subject { described_class.new(admin, unrelated_order) }
      it { is_expected.to permit_action(:show) }
    end

    context 'as production_manager viewing order they created' do
      subject { described_class.new(production_manager, order_created_by_manager) }
      it { is_expected.to permit_action(:show) }
    end

    context 'as operator viewing order they are assigned to' do
      subject { described_class.new(operator, order_with_assigned_operator) }
      it { is_expected.to permit_action(:show) }
    end

    context 'as operator viewing unrelated order' do
      subject { described_class.new(other_operator, unrelated_order) }
      it { is_expected.to forbid_action(:show) }
    end
  end

  describe '#create?' do
    subject { described_class.new(user, ProductionOrder.new) }

    context 'as admin' do
      let(:user) { admin }
      it { is_expected.to permit_action(:create) }
    end

    context 'as production_manager' do
      let(:user) { production_manager }
      it { is_expected.to permit_action(:create) }
    end

    context 'as operator' do
      let(:user) { operator }
      it { is_expected.to forbid_action(:create) }
    end
  end

  describe '#update?' do
    context 'as admin updating any order' do
      subject { described_class.new(admin, unrelated_order) }
      it { is_expected.to permit_action(:update) }
    end

    context 'as production_manager updating order they created' do
      subject { described_class.new(production_manager, order_created_by_manager) }
      it { is_expected.to permit_action(:update) }
    end

    context 'as production_manager updating order they are assigned to' do
      let(:order) { create(:normal_order, creator: admin) }
      before { create(:order_assignment, user: production_manager, production_order: order) }
      subject { described_class.new(production_manager, order) }
      it { is_expected.to permit_action(:update) }
    end

    context 'as operator updating order' do
      subject { described_class.new(operator, order_with_assigned_operator) }
      it { is_expected.to forbid_action(:update) }
    end

    context 'as production_manager updating unrelated order' do
      subject { described_class.new(production_manager, unrelated_order) }
      it { is_expected.to forbid_action(:update) }
    end
  end

  describe '#destroy?' do
    context 'as admin deleting any order' do
      subject { described_class.new(admin, unrelated_order) }
      it { is_expected.to permit_action(:destroy) }
    end

    context 'as production_manager deleting order they created' do
      subject { described_class.new(production_manager, order_created_by_manager) }
      it { is_expected.to permit_action(:destroy) }
    end

    context 'as production_manager deleting order they did not create (even if assigned)' do
      let(:order_assigned_to_pm) { create(:normal_order, creator: admin) }
      before { create(:order_assignment, user: production_manager, production_order: order_assigned_to_pm) }
      subject { described_class.new(production_manager, order_assigned_to_pm) }
      it { is_expected.to forbid_action(:destroy) }
    end

    context 'as operator deleting order' do
      subject { described_class.new(operator, order_with_assigned_operator) }
      it { is_expected.to forbid_action(:destroy) }
    end
  end

  describe '#tasks_summary?' do
    context 'as admin' do
      subject { described_class.new(admin, unrelated_order) }
      it { is_expected.to permit_action(:tasks_summary) }
    end

    context 'as production_manager with their order' do
      subject { described_class.new(production_manager, order_created_by_manager) }
      it { is_expected.to permit_action(:tasks_summary) }
    end

    context 'as operator with assigned order' do
      subject { described_class.new(operator, order_with_assigned_operator) }
      it { is_expected.to permit_action(:tasks_summary) }
    end

    context 'as operator with unrelated order' do
      subject { described_class.new(other_operator, unrelated_order) }
      it { is_expected.to forbid_action(:tasks_summary) }
    end
  end

  describe 'report permissions' do
    describe '#monthly_statistics?' do
      subject { described_class.new(user, ProductionOrder) }

      context 'as admin' do
        let(:user) { admin }
        it { is_expected.to permit_action(:monthly_statistics) }
      end

      context 'as production_manager' do
        let(:user) { production_manager }
        it { is_expected.to permit_action(:monthly_statistics) }
      end

      context 'as operator' do
        let(:user) { operator }
        it { is_expected.to permit_action(:monthly_statistics) }
      end
    end

    describe '#urgent_orders_report?' do
      subject { described_class.new(user, ProductionOrder) }

      context 'as admin' do
        let(:user) { admin }
        it { is_expected.to permit_action(:urgent_orders_report) }
      end

      context 'as production_manager' do
        let(:user) { production_manager }
        it { is_expected.to permit_action(:urgent_orders_report) }
      end

      context 'as operator' do
        let(:user) { operator }
        it { is_expected.to permit_action(:urgent_orders_report) }
      end
    end

    describe '#urgent_with_expired_tasks?' do
      subject { described_class.new(user, ProductionOrder) }

      context 'as admin' do
        let(:user) { admin }
        it { is_expected.to permit_action(:urgent_with_expired_tasks) }
      end

      context 'as production_manager' do
        let(:user) { production_manager }
        it { is_expected.to permit_action(:urgent_with_expired_tasks) }
      end

      context 'as operator' do
        let(:user) { operator }
        it { is_expected.to permit_action(:urgent_with_expired_tasks) }
      end
    end
  end
end
