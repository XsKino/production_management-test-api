# Temporary schedule file for TESTING ONLY
# This runs jobs every minute so you can test cron execution quickly
#
# To use this test schedule:
# 1. RAILS_ENV=development bundle exec whenever --set environment=development --update-crontab --load-file config/schedule_test.rb
# 2. Watch logs: tail -f log/whenever.log log/whenever_error.log
# 3. Remove when done: bundle exec whenever --clear-crontab
#
# IMPORTANT: Do NOT use this in production!

set :environment, 'development'
set :output, { error: 'log/whenever_error.log', standard: 'log/whenever.log' }

# Run every minute for testing
every 1.minute do
  runner "ExpiredTasksNotificationJob.perform_later"
end

# Run every 2 minutes for testing
every 2.minutes do
  runner "UrgentDeadlineReminderJob.perform_later"
end
