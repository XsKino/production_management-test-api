# frozen_string_literal: true

class UrgentDeadlineReminderJob < ApplicationJob
  queue_as :critical

  def perform
    # Find urgent orders with deadlines approaching (within 24-48 hours)
    upcoming_deadlines = UrgentOrder.where(status: :pending)
                                    .where('deadline BETWEEN ? AND ?',
                                           Date.current + 1.day,
                                           Date.current + 2.days)
                                    .includes(:creator, :assigned_users)

    return if upcoming_deadlines.empty?

    Rails.logger.info "Found #{upcoming_deadlines.count} urgent orders with approaching deadlines"

    upcoming_deadlines.find_each do |order|
      days_until_deadline = (order.deadline - Date.current).to_i

      # Get all users that should be notified (creator + assigned users)
      users_to_notify = ([order.creator] + order.assigned_users.to_a).uniq

      users_to_notify.each do |user|
        Rails.logger.info "Urgent order #{order.order_number} deadline approaching in #{days_until_deadline} day(s). " \
                          "Deadline: #{order.deadline}. Notifying user: #{user.email}"

        # Send email notification
        NotificationMailer.urgent_deadline_reminder(user, order, days_until_deadline).deliver_later
      end
    end

    Rails.logger.info "Urgent deadline reminder job completed"
  end
end
