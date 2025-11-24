# frozen_string_literal: true

class NotificationMailer < ApplicationMailer
  default from: 'mail@xskino.com'

  # Send notification about expired task
  # @param user [User] The user to notify
  # @param task [Task] The expired task
  def expired_task_notification(user, task)
    @user = user
    @task = task
    @order = task.production_order

    mail(
      to: user.email,
      subject: "⚠️ Overdue Task - Order #{@order.order_number}"
    )
  end

  # Send reminder about urgent order deadline
  # @param user [User] The user to notify
  # @param order [UrgentOrder] The urgent order
  # @param days_until_deadline [Integer] Days remaining until deadline
  def urgent_deadline_reminder(user, order, days_until_deadline)
    @user = user
    @order = order
    @days_until_deadline = days_until_deadline

    mail(
      to: user.email,
      subject: "🚨 Reminder: Urgent Order #{@order.order_number} expires in #{days_until_deadline} day(s)"
    )
  end
end
