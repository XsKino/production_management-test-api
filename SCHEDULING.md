# Background Jobs Scheduling

This project uses **Sidekiq** for background jobs and **Whenever** for automated scheduling via cron.

## Configured Jobs

### 1. ExpiredTasksNotificationJob
- **Description**: Notifies users about overdue tasks
- **Frequency**: Daily at 2:00 AM
- **What it does**:
  - Finds all tasks with `pending` status and `expected_end_date < Date.current`
  - Notifies the order creator and all assigned users
  - Logs each notification sent

### 2. UrgentDeadlineReminderJob
- **Description**: Reminds about urgent order deadlines approaching expiration
- **Frequency**: Daily at 9:00 AM and 5:00 PM
- **What it does**:
  - Finds urgent orders with `deadline` between 1-2 days in the future
  - Notifies the order creator and all assigned users
  - Includes information about how many days until deadline

## Schedule Installation

### In development (local)

```bash
# 1. Verify the generated schedule (doesn't update crontab)
bundle exec whenever

# 2. Install to your user's crontab
bundle exec whenever --update-crontab

# 3. View the installed crontab
crontab -l

# 4. Remove schedule from crontab (if needed)
bundle exec whenever --clear-crontab
```

### In production

```bash
# On the production server, install schedule
cd /path/to/app
RAILS_ENV=production bundle exec whenever --update-crontab

# Verify it was installed
crontab -l
```

## Manual Job Execution

### From Rails Console

```ruby
# Execute immediately (synchronous)
ExpiredTasksNotificationJob.perform_now
UrgentDeadlineReminderJob.perform_now

# Queue for background (asynchronous with Sidekiq)
ExpiredTasksNotificationJob.perform_later
UrgentDeadlineReminderJob.perform_later

# Queue to execute at a specific time
ExpiredTasksNotificationJob.set(wait: 1.hour).perform_later
UrgentDeadlineReminderJob.set(wait_until: Date.tomorrow.noon).perform_later
```

### From command line

```bash
# Execute job immediately
bundle exec rails runner "ExpiredTasksNotificationJob.perform_now"

# Queue job for background
bundle exec rails runner "UrgentDeadlineReminderJob.perform_later"
```

## Monitoring

### Whenever Logs

Cron execution logs are saved in:
- `log/whenever.log` - Standard output
- `log/whenever_error.log` - Errors

### Sidekiq Logs

Job execution logs are found in:
- `log/development.log` (development)
- `log/production.log` (production)

Search for:
```bash
grep "ExpiredTasksNotificationJob" log/production.log
grep "UrgentDeadlineReminderJob" log/production.log
```

### Sidekiq Dashboard (optional)

If you mount Sidekiq Web UI in `routes.rb`:
```ruby
require 'sidekiq/web'
mount Sidekiq::Web => '/sidekiq'
```

Access at: `http://localhost:3000/sidekiq`

## Requirements

### Redis
Sidekiq requires Redis running:

```bash
# macOS
brew services start redis

# Linux
sudo systemctl start redis

# Verify it's running
redis-cli ping  # Should respond: PONG
```

### Sidekiq Workers

In production, you need Sidekiq workers running:

```bash
# Start worker manually
bundle exec sidekiq

# Or with systemd (production)
sudo systemctl start sidekiq

# Or with Procfile (Heroku, Render, etc.)
web: bundle exec puma -C config/puma.rb
worker: bundle exec sidekiq -C config/sidekiq.yml
```

## Modifying the Schedule

Edit `config/schedule.rb` and update:

```ruby
# Change time
every 1.day, at: '3:00 am' do
  runner "ExpiredTasksNotificationJob.perform_later"
end

# Change frequency
every 12.hours do
  runner "UrgentDeadlineReminderJob.perform_later"
end

# Use direct cron syntax
every '0 */6 * * *' do  # Every 6 hours
  runner "SomeJob.perform_later"
end
```

Then update the crontab:
```bash
bundle exec whenever --update-crontab
```

## Troubleshooting

### Jobs don't execute

1. Verify crontab is installed:
   ```bash
   crontab -l
   ```

2. Verify Redis is running:
   ```bash
   redis-cli ping
   ```

3. Verify Sidekiq is running:
   ```bash
   ps aux | grep sidekiq
   ```

4. Review logs:
   ```bash
   tail -f log/whenever_error.log
   tail -f log/production.log
   ```

### Jobs fail

1. Execute manually to see the error:
   ```bash
   bundle exec rails runner "ExpiredTasksNotificationJob.perform_now"
   ```

2. Review Sidekiq dashboard (if mounted)

3. Verify database permissions and environment variables

## Deployment

### Heroku / Render

Add worker dyno in `Procfile`:
```
web: bundle exec puma -C config/puma.rb
worker: bundle exec sidekiq -C config/sidekiq.yml
```

Add Redis addon and update crontab with Heroku Scheduler or similar.

### VPS / Dedicated Server

1. Install Redis
2. Configure systemd for Sidekiq
3. Install crontab with `whenever --update-crontab`
4. Configure environment variables

## Next Steps

When implementing actual notification sending:

1. Configure ActionMailer or email service (SendGrid, Mailgun, etc.)
2. Update jobs to call mailers
3. Add email templates
4. Configure push notifications if needed
