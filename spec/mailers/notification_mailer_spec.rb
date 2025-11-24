require 'rails_helper'

RSpec.describe NotificationMailer, type: :mailer do
  let(:creator) { create(:user, role: :production_manager, email: 'manager@test.com', name: 'Manager') }
  let(:operator) { create(:user, role: :operator, email: 'operator@test.com', name: 'Operator') }

  describe '#expired_task_notification' do
    let(:order) { create(:normal_order, creator: creator) }
    let(:task) { create(:task, production_order: order, expected_end_date: 3.days.ago, status: :pending) }
    let(:mail) { NotificationMailer.expired_task_notification(operator, task) }

    it 'renders the headers' do
      expect(mail.subject).to eq("⚠️ Overdue Task - Order #{order.order_number}")
      expect(mail.to).to eq([operator.email])
      expect(mail.from).to eq(['mail@xskino.com'])
    end

    it 'renders the body with task details' do
      html_part = mail.html_part.body.to_s
      text_part = mail.text_part.body.to_s

      expect(html_part).to include(operator.name)
      expect(html_part).to include(task.description)
      expect(text_part).to include('OVERDUE')
    end

    it 'includes days overdue' do
      text_part = mail.text_part.body.to_s
      days_overdue = (Date.current - task.expected_end_date).to_i
      expect(text_part).to include("#{days_overdue} day")
    end
  end

  describe '#urgent_deadline_reminder' do
    let(:order) { create(:urgent_order, creator: creator, deadline: Date.current + 1.day) }
    let(:mail) { NotificationMailer.urgent_deadline_reminder(operator, order, 1) }

    it 'renders the headers' do
      expect(mail.subject).to eq("🚨 Reminder: Urgent Order #{order.order_number} expires in 1 day(s)")
      expect(mail.to).to eq([operator.email])
      expect(mail.from).to eq(['mail@xskino.com'])
    end

    it 'renders the body with order details' do
      html_part = mail.html_part.body.to_s
      text_part = mail.text_part.body.to_s

      expect(html_part).to include(operator.name)
      expect(text_part).to include('urgent')
    end

    context 'when deadline is 1 day away' do
      it 'shows high urgency message' do
        text_part = mail.text_part.body.to_s
        expect(text_part).to include('TOMORROW')
      end
    end

    context 'when deadline is 2 days away' do
      let(:order) { create(:urgent_order, creator: creator, deadline: Date.current + 2.days) }
      let(:mail) { NotificationMailer.urgent_deadline_reminder(operator, order, 2) }

      it 'shows medium urgency message' do
        text_part = mail.text_part.body.to_s
        expect(text_part).to include('2 day')
      end
    end
  end
end
