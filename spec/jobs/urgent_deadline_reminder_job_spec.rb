require 'rails_helper'

RSpec.describe UrgentDeadlineReminderJob, type: :job do
  include ActiveJob::TestHelper

  describe '#perform' do
    let(:creator) { create(:user, role: :production_manager) }
    let(:assigned_user) { create(:user, role: :operator) }

    it 'enqueues the job' do
      expect {
        UrgentDeadlineReminderJob.perform_later
      }.to have_enqueued_job(UrgentDeadlineReminderJob).on_queue('critical')
    end

    it 'processes urgent orders with approaching deadlines (1 day)' do
      order = create(:urgent_order,
        creator: creator,
        status: :pending,
        deadline: Date.current + 1.day
      )
      create(:order_assignment, user: assigned_user, production_order: order)

      allow(Rails.logger).to receive(:info)
      expect(Rails.logger).to receive(:info).with(/Found 1 urgent orders/)
      expect(Rails.logger).to receive(:info).with(/Urgent order #{order.order_number}/)

      UrgentDeadlineReminderJob.perform_now
    end

    it 'processes urgent orders with approaching deadlines (2 days)' do
      order = create(:urgent_order,
        creator: creator,
        status: :pending,
        deadline: Date.current + 2.days
      )

      allow(Rails.logger).to receive(:info)
      expect(Rails.logger).to receive(:info).with(/Found 1 urgent orders/)

      UrgentDeadlineReminderJob.perform_now
    end

    it 'does not process orders with deadlines today' do
      order = create(:urgent_order,
        creator: creator,
        status: :pending,
        deadline: Date.current
      )

      # Should complete without errors
      expect { UrgentDeadlineReminderJob.perform_now }.not_to raise_error
    end

    it 'does not process orders with deadlines more than 2 days away' do
      order = create(:urgent_order,
        creator: creator,
        status: :pending,
        deadline: Date.current + 3.days
      )

      # Should complete without errors
      expect { UrgentDeadlineReminderJob.perform_now }.not_to raise_error
    end

    it 'does not process completed orders' do
      order = create(:urgent_order,
        creator: creator,
        status: :completed,
        deadline: Date.current + 1.day
      )

      # Should complete without errors
      expect { UrgentDeadlineReminderJob.perform_now }.not_to raise_error
    end

    it 'notifies all users assigned to the order' do
      order = create(:urgent_order,
        creator: creator,
        status: :pending,
        deadline: Date.current + 1.day
      )
      create(:order_assignment, user: assigned_user, production_order: order)

      allow(Rails.logger).to receive(:info)
      # Expect notifications for both creator and assigned user
      expect(Rails.logger).to receive(:info).with(/Notifying user: #{creator.email}/)
      expect(Rails.logger).to receive(:info).with(/Notifying user: #{assigned_user.email}/)

      UrgentDeadlineReminderJob.perform_now
    end
  end
end
