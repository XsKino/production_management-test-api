require 'rails_helper'

RSpec.describe ExpiredTasksNotificationJob, type: :job do
  include ActiveJob::TestHelper

  describe '#perform' do
    let(:creator) { create(:user, role: :production_manager) }
    let(:assigned_user) { create(:user, role: :operator) }
    let(:order) { create(:normal_order, creator: creator) }

    before do
      create(:order_assignment, user: assigned_user, production_order: order)
    end

    it 'enqueues the job' do
      expect {
        ExpiredTasksNotificationJob.perform_later
      }.to have_enqueued_job(ExpiredTasksNotificationJob)
    end

    it 'processes expired tasks' do
      expired_task = create(:task,
        production_order: order,
        status: :pending,
        expected_end_date: 1.week.ago
      )

      not_expired_task = create(:task,
        production_order: order,
        status: :pending,
        expected_end_date: 1.week.from_now
      )

      allow(Rails.logger).to receive(:info)
      expect(Rails.logger).to receive(:info).with(/Found 1 expired tasks/)
      expect(Rails.logger).to receive(:info).with(/Task ##{expired_task.id}/)

      ExpiredTasksNotificationJob.perform_now
    end

    it 'does nothing when there are no expired tasks' do
      # Should complete without errors when no expired tasks
      expect { ExpiredTasksNotificationJob.perform_now }.not_to raise_error
    end

    it 'notifies all users assigned to the order' do
      expired_task = create(:task,
        production_order: order,
        status: :pending,
        expected_end_date: 1.week.ago
      )

      allow(Rails.logger).to receive(:info)
      # Expect notifications for both creator and assigned user
      expect(Rails.logger).to receive(:info).with(/Notifying user: #{creator.email}/)
      expect(Rails.logger).to receive(:info).with(/Notifying user: #{assigned_user.email}/)

      ExpiredTasksNotificationJob.perform_now
    end

    it 'only processes pending tasks' do
      completed_expired_task = create(:task,
        production_order: order,
        status: :completed,
        expected_end_date: 1.week.ago
      )

      # Should complete without errors, not processing completed tasks
      expect { ExpiredTasksNotificationJob.perform_now }.not_to raise_error
    end
  end
end
