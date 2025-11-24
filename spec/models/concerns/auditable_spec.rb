require 'rails_helper'

RSpec.describe Auditable, type: :model do
  let(:admin) { create(:user, role: :admin) }
  let(:order) { create(:normal_order, creator: admin) }

  before do
    Current.user = admin
    Current.ip_address = '192.168.1.1'
    Current.user_agent = 'RSpec Test'
  end

  after do
    Current.reset
  end

  describe 'audit logging on create' do
    it 'creates an audit log when order is created' do
      expect {
        create(:normal_order, creator: admin)
      }.to change(OrderAuditLog, :count).by(1)

      log = OrderAuditLog.last
      expect(log.action).to eq('created')
      expect(log.user).to eq(admin)
      expect(log.ip_address).to eq('192.168.1.1')
      expect(log.user_agent).to eq('RSpec Test')
    end
  end

  describe 'audit logging on update' do
    it 'creates an audit log when order is updated' do
      order # Create the order first

      expect {
        order.update!(status: :completed)
      }.to change(OrderAuditLog, :count).by(1)

      log = OrderAuditLog.last
      expect(log.action).to eq('status_changed')
      expect(log.user).to eq(admin)
      expect(log.change_details['status']['from']).to eq('pending')
      expect(log.change_details['status']['to']).to eq('completed')
    end

    it 'creates audit log with action type_changed when type changes' do
      order # Create the order first

      expect {
        order.update!(type: 'UrgentOrder')
      }.to change(OrderAuditLog, :count).by(1)

      log = OrderAuditLog.last
      expect(log.action).to eq('type_changed')
    end

    it 'creates audit log with action updated for other changes' do
      order # Create the order first

      expect {
        order.update!(expected_end_date: 10.days.from_now)
      }.to change(OrderAuditLog, :count).by(1)

      log = OrderAuditLog.last
      expect(log.action).to eq('updated')
    end

    it 'does not create audit log when no changes are saved' do
      order # Create the order first

      expect {
        order.update(status: order.status)
      }.to change(OrderAuditLog, :count).by(0)
    end
  end

  describe 'audit logging on destroy' do
    it 'creates an audit log when order is destroyed' do
      order # Create the order first

      expect {
        order.destroy
      }.to change(OrderAuditLog, :count).by(1)

      log = OrderAuditLog.last
      expect(log.action).to eq('deleted')
      expect(log.user).to eq(admin)
    end
  end

  describe 'without Current.user set' do
    before do
      Current.reset
    end

    it 'does not create audit log on create' do
      expect {
        create(:normal_order, creator: admin)
      }.to change(OrderAuditLog, :count).by(0)
    end

    it 'does not create audit log on update' do
      Current.user = admin
      order = create(:normal_order, creator: admin)
      Current.reset

      expect {
        order.update!(status: :completed)
      }.to change(OrderAuditLog, :count).by(0)
    end
  end
end
