# Use this file to easily define all of your cron jobs.
#
# It's helpful, but not entirely necessary to understand cron before proceeding.
# http://en.wikipedia.org/wiki/Cron

# Learn more: http://github.com/javan/whenever

# Set environment
set :environment, ENV['RAILS_ENV'] || 'production'

# Set output to log file
set :output, { error: 'log/whenever_error.log', standard: 'log/whenever.log' }

# Run expired tasks notification job every day at 2:00 AM
every 1.day, at: '2:00 am' do
  runner "ExpiredTasksNotificationJob.perform_later"
end

# Run urgent deadline reminder job every day at 9:00 AM
every 1.day, at: '9:00 am' do
  runner "UrgentDeadlineReminderJob.perform_later"
end

# Optional: Run urgent deadline reminder also at 5:00 PM (second daily check)
every 1.day, at: '5:00 pm' do
  runner "UrgentDeadlineReminderJob.perform_later"
end

# Example: Monthly statistics report (first day of each month at 8:00 AM)
# every '0 8 1 * *' do
#   runner "MonthlyStatisticsReportJob.perform_later"
# end

# Example: Weekly report (every Monday at 8:00 AM)
# every :monday, at: '8:00 am' do
#   runner "WeeklyReportJob.perform_later"
# end
