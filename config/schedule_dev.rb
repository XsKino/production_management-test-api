# Development schedule - runs at convenient times for testing
# To use: RAILS_ENV=development bundle exec whenever --set environment=development --update-crontab --load-file config/schedule_dev.rb

set :environment, 'development'
set :output, { error: 'log/whenever_error.log', standard: 'log/whenever.log' }

# Get current time and set jobs to run in the next few minutes
# Adjust these times to a few minutes from now
# For example, if it's 10:30 AM, set these to 10:32 AM, 10:34 AM, etc.

# Run expired tasks notification - adjust this time!
every 1.day, at: '10:35 am' do
  runner "ExpiredTasksNotificationJob.perform_later"
end

# Run urgent deadline reminder - adjust this time!
every 1.day, at: '10:36 am' do
  runner "UrgentDeadlineReminderJob.perform_later"
end

# Or use this format to run every N hours
# every 2.hours do
#   runner "ExpiredTasksNotificationJob.perform_later"
# end
