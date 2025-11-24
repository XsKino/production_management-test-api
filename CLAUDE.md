# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Rails 8.1 API-only application for managing production orders with a focus on manufacturing workflow. Uses MySQL database and includes background job processing via Sidekiq.

## Development Commands

### Database
```bash
# Prepare test database (required after schema changes or when tests have stale data)
bundle exec rails db:test:prepare

# Reset development database
bundle exec rails db:reset
```

### Testing
```bash
# Run all tests
bundle exec rspec

# Run specific test file
bundle exec rspec spec/models/production_order_spec.rb

# Run specific test by line number
bundle exec rspec spec/models/production_order_spec.rb:31

# Run with documentation format
bundle exec rspec spec/ --format documentation
```

**Important**: If tests fail with unexpected counts or data, run `bundle exec rails db:test:prepare` to clean the test database.

## Architecture

### Single Table Inheritance (STI) Pattern

ProductionOrder uses STI with two subclasses:
- `NormalOrder` - Standard production orders
- `UrgentOrder` - Orders with deadlines

**Critical**: The `type` column is NOT NULL. When creating orders:
- Without type specified → defaults to `NormalOrder`
- Never instantiate `ProductionOrder` directly, always use a subclass

Each order type maintains separate auto-incrementing `order_number` sequences scoped by type.

### API Structure

All endpoints are namespaced under `/api/v1/`. The API uses:
- JSON format exclusively
- Simple token-based authentication via `Authorization: Bearer {user_id}` header (placeholder for proper JWT implementation)
- Standardized response format with `success`, `data`, `message`, and `meta` keys
- Pagination metadata nested under `meta.pagination`

### Response Helpers

Located in `app/controllers/concerns/api/response_helpers.rb`:
- `render_success(data, message, status, meta)` - Standard success responses
- `render_error(message, status, errors, code)` - Error responses
- `render_paginated_success(data, pagination_object, message)` - For paginated endpoints

Pagination metadata structure:
```json
{
  "meta": {
    "pagination": {
      "current_page": 1,
      "total_pages": 5,
      "total_count": 100,
      "per_page": 20,
      "has_next_page": true,
      "has_prev_page": false
    }
  }
}
```

### Ransack Search Configuration

All models require explicit `ransackable_attributes` and `ransackable_associations` methods for security. When adding new models or making fields searchable, always define these methods.

Example:
```ruby
def self.ransackable_attributes(auth_object = nil)
  ["field1", "field2", "created_at", "updated_at"]
end

def self.ransackable_associations(auth_object = nil)
  ["association1", "association2"]
end
```

### User Roles & Authorization with Pundit

Three role levels (string-based):
- `operator` - Read-only access to assigned orders, can only change task status
- `production_manager` - Can create/manage orders and tasks they're assigned to or created
- `admin` - Full access to all resources

**Pundit Implementation**: Fully integrated with policies for all resources:

#### Policy Classes
- `ProductionOrderPolicy` - Base policy for production orders
  - `NormalOrderPolicy` - Inherits from ProductionOrderPolicy (for STI)
  - `UrgentOrderPolicy` - Inherits from ProductionOrderPolicy (for STI)
- `TaskPolicy` - Policies for task operations
- `UserPolicy` - Policies for user management

#### Key Authorization Rules

**Production Orders:**
- Admin: Full CRUD on all orders
- Production Manager: Can create orders, CRUD on assigned/created orders
- Operator: Can only view assigned orders (read-only)

**Tasks:**
- Admin: Full CRUD on all tasks
- Production Manager: Full CRUD on tasks from assigned/created orders
- Operator: Can only complete/reopen tasks from assigned orders (no create/update/delete)

**Users:**
- Admin: Full CRUD on all users
- Production Manager/Operator: Can view all users, update own profile only

#### Scopes
Pundit scopes automatically filter records based on role:
- Admin: See everything
- Manager/Operator: Only see orders/tasks they're assigned to or created

#### Usage in Controllers
```ruby
# Authorize single record
authorize @production_order

# Authorize collection (index actions)
authorize ProductionOrder

# Apply scope filtering
@orders = policy_scope(ProductionOrder)

# Authorize custom actions
authorize @task, :complete?
```

#### Authorization Errors
Pundit raises `Pundit::NotAuthorizedError` which is caught by `ApplicationController` and returns:
```json
{
  "success": false,
  "message": "You are not authorized to perform this action",
  "code": "FORBIDDEN"
}
```

### Order-Task Relationship

Orders have nested tasks via `accepts_nested_attributes_for :tasks`. Tasks can be:
- Created with orders via `tasks_attributes`
- Managed independently via `/api/v1/production_orders/:production_order_id/tasks`
- Marked complete/reopened via custom endpoints

### Date Fields

Important distinction:
- `start_date`, `expected_end_date`, `deadline` are `date` type (no time component)
- In tests, use `.to_date` when converting from Time objects
- For date range queries in specs, ensure dates fall within the expected period (e.g., use `Date.current.end_of_month` instead of `2.weeks.from_now`)

### Background Jobs with Sidekiq

**Configuration:**
- ActiveJob configured to use Sidekiq adapter
- Redis running on `localhost:6379` (configurable via `REDIS_URL` env var)
- Three queues: `critical`, `default`, `low`
- Configuration file: `config/sidekiq.yml`

**Implemented Jobs:**

**ExpiredTasksNotificationJob** (queue: `default`)
- Finds all pending tasks with `expected_end_date < Date.current`
- Notifies creator and assigned users for each expired task
- Run manually: `ExpiredTasksNotificationJob.perform_later`
- Typical schedule: Daily at 2:00 AM

**UrgentDeadlineReminderJob** (queue: `critical`)
- Finds urgent orders with deadlines 1-2 days away
- Notifies creator and assigned users
- Run manually: `UrgentDeadlineReminderJob.perform_later`
- Typical schedule: Daily at 9:00 AM

**Running Sidekiq:**
```bash
# Start Redis server
redis-server

# Start Sidekiq worker (in separate terminal)
bundle exec sidekiq

# Run job immediately in console
ExpiredTasksNotificationJob.perform_now

# Enqueue job for background processing
ExpiredTasksNotificationJob.perform_later
```

**Scheduling Jobs (Whenever):**
- Jobs are automatically scheduled via cron using the `whenever` gem
- Configuration: `config/schedule.rb`
- ExpiredTasksNotificationJob: Daily at 2:00 AM
- UrgentDeadlineReminderJob: Daily at 9:00 AM and 5:00 PM

```bash
# Preview crontab
bundle exec whenever

# Install to crontab
bundle exec whenever --update-crontab

# Remove from crontab
bundle exec whenever --clear-crontab
```

**Testing Jobs:**
- Test environment uses `:test` adapter (not Sidekiq)
- Use `perform_now` for synchronous execution in tests
- Jobs inherit from `ApplicationJob` with auto-retry on deadlocks

See [SCHEDULING.md](SCHEDULING.md) for complete scheduling documentation.

## Testing Patterns

### RSpec Configuration
- Uses transactional fixtures
- FactoryBot for test data
- Shoulda matchers for model validations
- Pundit matchers for policy testing (pundit-matchers gem v4.0)
- Request specs for integration testing

### Common Test Patterns

**Controller specs**: Use `JSON.parse(response.body)` to access response data.

**Model specs requiring subject**: Validators like `validate_uniqueness_of` need a subject:
```ruby
describe 'validations' do
  subject { build(:model_name) }
  it { should validate_uniqueness_of(:field) }
end
```

**Integration specs**: Use `as: :json` parameter, don't call `.to_json` on params:
```ruby
post "/api/v1/endpoint", headers: headers, params: params, as: :json
```

**Policy specs** (using pundit-matchers 4.0 syntax):
```ruby
RSpec.describe ProductionOrderPolicy, type: :policy do
  describe '#create?' do
    subject { described_class.new(user, ProductionOrder.new) }

    context 'as admin' do
      let(:user) { create(:user, role: 'admin') }
      it { is_expected.to permit_action(:create) }
    end

    context 'as operator' do
      let(:user) { create(:user, role: 'operator') }
      it { is_expected.to forbid_action(:create) }
    end
  end
end
```

**Important**: pundit-matchers v4.0 uses `permit_action(:action)` and `forbid_action(:action)` instead of the deprecated `permit(user, record)` syntax.

**Factory usage with STI**: Always use specific subclass factories:
```ruby
create(:normal_order)    # ✅ Correct
create(:urgent_order)    # ✅ Correct
create(:production_order) # ❌ Will fail - type column cannot be null
```

## Key Files

### Controllers & Concerns
- `app/controllers/concerns/api/error_handling.rb` - Centralized error handling
- `app/controllers/concerns/api/response_helpers.rb` - Standardized response formatting
- `app/controllers/api/v1/application_controller.rb` - Base API controller with auth, pagination helpers, and Pundit integration

### Models
- `app/models/production_order.rb` - Base STI model with auto-incrementing order numbers
- `app/models/normal_order.rb` - Standard production order
- `app/models/urgent_order.rb` - Urgent order with deadline
- `app/models/task.rb` - Tasks belonging to production orders
- `app/models/user.rb` - User model with role-based authentication
- `app/models/order_assignment.rb` - Join table for user-order assignments

### Policies (Pundit)
- `app/policies/application_policy.rb` - Base policy with default deny-all behavior
- `app/policies/production_order_policy.rb` - Authorization for production orders
- `app/policies/normal_order_policy.rb` - Inherits from ProductionOrderPolicy (for STI)
- `app/policies/urgent_order_policy.rb` - Inherits from ProductionOrderPolicy (for STI)
- `app/policies/task_policy.rb` - Authorization for tasks with operator restrictions
- `app/policies/user_policy.rb` - Authorization for user management

### Services
- `app/services/json_web_token.rb` - JWT encoding/decoding service

### Background Jobs (Sidekiq + Whenever)
- `app/jobs/application_job.rb` - Base job class with error handling
- `app/jobs/expired_tasks_notification_job.rb` - Notifies users about expired tasks
- `app/jobs/urgent_deadline_reminder_job.rb` - Reminds users about approaching urgent deadlines
- `config/sidekiq.yml` - Sidekiq configuration (queues, concurrency)
- `config/initializers/sidekiq.rb` - Redis connection configuration
- `config/schedule.rb` - Whenever cron job scheduling configuration
- `SCHEDULING.md` - Complete documentation for background job scheduling

### Test Files
- `spec/policies/` - Policy authorization tests (87 tests)
- `spec/jobs/` - Background job tests (12 tests)
- `spec/models/` - Model unit tests
- `spec/controllers/` - Controller tests
- `spec/requests/` - Integration/request tests
- `spec/factories/` - FactoryBot factory definitions
