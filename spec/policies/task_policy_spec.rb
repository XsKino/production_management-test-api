require 'rails_helper'

RSpec.describe TaskPolicy, type: :policy do
  let(:admin) { create(:user, role: 'admin') }
  let(:production_manager) { create(:user, role: 'production_manager') }
  let(:operator) { create(:user, role: 'operator') }
  let(:other_operator) { create(:user, role: 'operator') }

  let!(:order_created_by_manager) { create(:normal_order, creator: production_manager) }
  let!(:order_with_assigned_operator) { create(:normal_order, creator: production_manager) }
  let!(:unrelated_order) { create(:normal_order, creator: admin) }

  let!(:task_on_manager_order) { create(:task, production_order: order_created_by_manager) }
  let!(:task_on_assigned_order) { create(:task, production_order: order_with_assigned_operator) }
  let!(:task_on_unrelated_order) { create(:task, production_order: unrelated_order) }

  before do
    create(:order_assignment, user: operator, production_order: order_with_assigned_operator)
  end

  describe 'Scope' do
    it 'allows admin to see all tasks' do
      # Admin should see all 3 let! tasks
      scope = Pundit.policy_scope(admin, Task)
      expect(scope.count).to eq(3)
    end

    it 'allows production_manager to see tasks from orders they created' do
      # Production manager created 2 orders, so should see 2 tasks
      scope = Pundit.policy_scope(production_manager, Task)
      expect(scope.count).to eq(2)
    end

    it 'allows production_manager to see tasks from orders they are assigned to' do
      order = create(:normal_order, creator: admin)
      create(:order_assignment, user: production_manager, production_order: order)
      task = create(:task, production_order: order)
      scope = Pundit.policy_scope(production_manager, Task)
      # 2 tasks from created orders + 1 from assigned order = 3
      expect(scope.count).to eq(3)
    end

    it 'allows operator to see tasks from orders they are assigned to' do
      # Operator is assigned to order_with_assigned_operator (1 task)
      scope = Pundit.policy_scope(operator, Task)
      expect(scope.count).to eq(1)
    end
  end

  describe '#show?' do
    context 'as admin viewing any task' do
      subject { described_class.new(admin, task_on_unrelated_order) }
      it { is_expected.to permit_action(:show) }
    end

    context 'as production_manager viewing task from order they created' do
      subject { described_class.new(production_manager, task_on_manager_order) }
      it { is_expected.to permit_action(:show) }
    end

    context 'as operator viewing task from order they are assigned to' do
      subject { described_class.new(operator, task_on_assigned_order) }
      it { is_expected.to permit_action(:show) }
    end

    context 'as operator viewing task from unrelated order' do
      subject { described_class.new(other_operator, task_on_unrelated_order) }
      it { is_expected.to forbid_action(:show) }
    end
  end

  describe '#create?' do
    context 'as admin creating task on any order' do
      subject { described_class.new(admin, Task.new(production_order: unrelated_order)) }
      it { is_expected.to permit_action(:create) }
    end

    context 'as production_manager creating task on order they created' do
      subject { described_class.new(production_manager, Task.new(production_order: order_created_by_manager)) }
      it { is_expected.to permit_action(:create) }
    end

    context 'as production_manager creating task on order they are assigned to' do
      let(:order) { create(:normal_order, creator: admin) }
      before { create(:order_assignment, user: production_manager, production_order: order) }
      subject { described_class.new(production_manager, Task.new(production_order: order)) }
      it { is_expected.to permit_action(:create) }
    end

    context 'as production_manager creating task on unrelated order' do
      subject { described_class.new(production_manager, Task.new(production_order: unrelated_order)) }
      it { is_expected.to forbid_action(:create) }
    end

    context 'as operator creating task' do
      subject { described_class.new(operator, Task.new(production_order: order_with_assigned_operator)) }
      it { is_expected.to forbid_action(:create) }
    end
  end

  describe '#update?' do
    context 'as admin updating any task' do
      subject { described_class.new(admin, task_on_unrelated_order) }
      it { is_expected.to permit_action(:update) }
    end

    context 'as production_manager updating task from order they created' do
      subject { described_class.new(production_manager, task_on_manager_order) }
      it { is_expected.to permit_action(:update) }
    end

    context 'as production_manager updating task from order they are assigned to' do
      subject { described_class.new(production_manager, task_on_assigned_order) }
      it { is_expected.to permit_action(:update) }
    end

    context 'as production_manager updating task on unrelated order' do
      subject { described_class.new(production_manager, task_on_unrelated_order) }
      it { is_expected.to forbid_action(:update) }
    end

    context 'as operator updating task' do
      subject { described_class.new(operator, task_on_assigned_order) }
      it { is_expected.to forbid_action(:update) }
    end
  end

  describe '#destroy?' do
    context 'as admin deleting any task' do
      subject { described_class.new(admin, task_on_unrelated_order) }
      it { is_expected.to permit_action(:destroy) }
    end

    context 'as production_manager deleting task from order they created' do
      subject { described_class.new(production_manager, task_on_manager_order) }
      it { is_expected.to permit_action(:destroy) }
    end

    context 'as production_manager deleting task from order they are assigned to' do
      subject { described_class.new(production_manager, task_on_assigned_order) }
      it { is_expected.to permit_action(:destroy) }
    end

    context 'as production_manager deleting task on unrelated order' do
      subject { described_class.new(production_manager, task_on_unrelated_order) }
      it { is_expected.to forbid_action(:destroy) }
    end

    context 'as operator deleting task' do
      subject { described_class.new(operator, task_on_assigned_order) }
      it { is_expected.to forbid_action(:destroy) }
    end
  end

  describe '#complete?' do
    context 'as admin completing any task' do
      subject { described_class.new(admin, task_on_unrelated_order) }
      it { is_expected.to permit_action(:complete) }
    end

    context 'as production_manager completing task from order they created' do
      subject { described_class.new(production_manager, task_on_manager_order) }
      it { is_expected.to permit_action(:complete) }
    end

    context 'as production_manager completing task from order they are assigned to' do
      subject { described_class.new(production_manager, task_on_assigned_order) }
      it { is_expected.to permit_action(:complete) }
    end

    context 'as operator completing task from order they are assigned to' do
      subject { described_class.new(operator, task_on_assigned_order) }
      it { is_expected.to permit_action(:complete) }
    end

    context 'as operator completing task on unrelated order' do
      subject { described_class.new(other_operator, task_on_unrelated_order) }
      it { is_expected.to forbid_action(:complete) }
    end
  end

  describe '#reopen?' do
    context 'as admin reopening any task' do
      subject { described_class.new(admin, task_on_unrelated_order) }
      it { is_expected.to permit_action(:reopen) }
    end

    context 'as production_manager reopening task from order they created' do
      subject { described_class.new(production_manager, task_on_manager_order) }
      it { is_expected.to permit_action(:reopen) }
    end

    context 'as production_manager reopening task from order they are assigned to' do
      subject { described_class.new(production_manager, task_on_assigned_order) }
      it { is_expected.to permit_action(:reopen) }
    end

    context 'as operator reopening task from order they are assigned to' do
      subject { described_class.new(operator, task_on_assigned_order) }
      it { is_expected.to permit_action(:reopen) }
    end

    context 'as operator reopening task on unrelated order' do
      subject { described_class.new(other_operator, task_on_unrelated_order) }
      it { is_expected.to forbid_action(:reopen) }
    end
  end
end
