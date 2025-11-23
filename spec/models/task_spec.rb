require 'rails_helper'

RSpec.describe Task, type: :model do
  describe 'associations' do
    it { should belong_to(:production_order) }
  end

  describe 'validations' do
    it { should validate_presence_of(:description) }
    it { should validate_presence_of(:expected_end_date) }
    it { should validate_presence_of(:status) }
  end

  describe 'enums' do
    it { should define_enum_for(:status).with_values(pending: 0, completed: 1) }
  end

  describe 'status methods' do
    let(:task) { create(:task) }

    it 'correctly identifies pending tasks' do
      task.update!(status: :pending) 
      expect(task.pending?).to be true
      expect(task.completed?).to be false
    end

    it 'correctly identifies completed tasks' do
      task.update!(status: :completed)
      expect(task.pending?).to be false
      expect(task.completed?).to be true
    end
  end

  describe 'dependent destroy with production order' do
    let(:order) { create(:normal_order) }
    let!(:task) { create(:task, production_order: order) }

    it 'is destroyed when production order is destroyed' do
      expect { order.destroy }.to change(Task, :count).by(-1)
    end
  end

  describe 'date validations' do
    it 'accepts valid expected_end_date' do
      task = build(:task, expected_end_date: 1.week.from_now)
      expect(task).to be_valid
    end

    it 'accepts past dates for expected_end_date' do
      task = build(:task, expected_end_date: 1.week.ago)
      expect(task).to be_valid
    end
  end

  describe 'factory' do
    it 'creates valid task' do
      task = build(:task)
      expect(task).to be_valid
    end

    it 'creates task with pending status by default' do
      task = create(:task)
      expect(task.status).to eq('pending')
    end
  end

  describe 'scopes and queries' do
    let(:order) { create(:normal_order) }
    let!(:pending_task) { create(:task, production_order: order, status: :pending) }
    let!(:completed_task) { create(:task, production_order: order, status: :completed) }

    it 'filters pending tasks' do
      pending_tasks = Task.where(status: :pending)
      expect(pending_tasks).to include(pending_task)
      expect(pending_tasks).not_to include(completed_task)
    end

    it 'filters completed tasks' do
      completed_tasks = Task.where(status: :completed)
      expect(completed_tasks).to include(completed_task)
      expect(completed_tasks).not_to include(pending_task)
    end
  end

  describe 'overdue tasks' do
    let(:order) { create(:normal_order) }

    it 'identifies overdue pending tasks' do
      overdue_task = create(:task, 
        production_order: order, 
        expected_end_date: 1.day.ago, 
        status: :pending
      )
      
      overdue_tasks = Task.where('expected_end_date < ? AND status = ?', Date.current, Task.statuses[:pending])
      expect(overdue_tasks).to include(overdue_task)
    end

    it 'does not include completed tasks as overdue' do
      completed_overdue = create(:task, 
        production_order: order, 
        expected_end_date: 1.day.ago, 
        status: :completed
      )
      
      overdue_tasks = Task.where('expected_end_date < ? AND status = ?', Date.current, Task.statuses[:pending])
      expect(overdue_tasks).not_to include(completed_overdue)
    end
  end
end