require 'rails_helper'

RSpec.describe OrderAuditLog, type: :model do
  describe 'associations' do
    it { should belong_to(:production_order).optional }
    it { should belong_to(:user) }
  end

  describe 'validations' do
    it { should validate_presence_of(:action) }
    it { should validate_inclusion_of(:action).in_array(OrderAuditLog::ACTIONS) }
  end

  describe 'scopes' do
    let(:order) { create(:normal_order) }
    let(:user) { create(:user) }
    let!(:log1) { create(:order_audit_log, production_order: order, user: user, action: 'created', created_at: 2.days.ago) }
    let!(:log2) { create(:order_audit_log, production_order: order, user: user, action: 'updated', created_at: 1.day.ago) }
    let!(:log3) { create(:order_audit_log, production_order: order, user: user, action: 'status_changed', created_at: Time.current) }

    describe '.recent' do
      it 'returns logs in descending order by created_at' do
        logs = OrderAuditLog.recent
        expect(logs.first).to eq(log3)
        expect(logs.last).to eq(log1)
      end
    end

    describe '.for_order' do
      let(:other_order) { create(:urgent_order) }
      let!(:other_log) { create(:order_audit_log, production_order: other_order, user: user) }

      it 'returns logs for specific order' do
        logs = OrderAuditLog.for_order(order.id)
        expect(logs).to include(log1, log2, log3)
        expect(logs).not_to include(other_log)
      end
    end

    describe '.by_user' do
      let(:other_user) { create(:user, email: 'other@example.com') }
      let!(:other_user_log) { create(:order_audit_log, production_order: order, user: other_user) }

      it 'returns logs by specific user' do
        logs = OrderAuditLog.by_user(user.id)
        expect(logs).to include(log1, log2, log3)
        expect(logs).not_to include(other_user_log)
      end
    end

    describe '.by_action' do
      it 'returns logs with specific action' do
        logs = OrderAuditLog.by_action('updated')
        expect(logs).to include(log2)
        expect(logs).not_to include(log1, log3)
      end
    end
  end

  describe 'serialization' do
    it 'serializes change_details as JSON' do
      log = create(:order_audit_log, change_details: { order_number: 1, status: 'pending' })
      log.reload
      expect(log.change_details).to be_a(Hash)
      expect(log.change_details['order_number']).to eq(1)
      expect(log.change_details['status']).to eq('pending')
    end
  end
end
