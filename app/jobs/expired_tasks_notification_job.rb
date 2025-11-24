# frozen_string_literal: true

class ExpiredTasksNotificationJob < ApplicationJob
  queue_as :default

  def perform
    # Find tasks that are expired (pending and past expected_end_date)
    expired_tasks = Task.where(status: :pending)
                        .where('expected_end_date < ?', Date.current)
                        .includes(production_order: [:creator, :assigned_users])

    return if expired_tasks.empty?

    Rails.logger.info "Found #{expired_tasks.count} expired tasks"

    expired_tasks.find_each do |task|
      # Get all users that should be notified (creator + assigned users)
      users_to_notify = ([task.production_order.creator] + task.production_order.assigned_users.to_a).uniq

      users_to_notify.each do |user|
        Rails.logger.info "Task ##{task.id} (Order: #{task.production_order.order_number}) is expired. " \
                          "Expected end: #{task.expected_end_date}. Notifying user: #{user.email}"

        # Send email notification
        NotificationMailer.expired_task_notification(user, task).deliver_later
      end
    end

    Rails.logger.info "Expired tasks notification job completed"
  end
end
