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

### User Roles & Authorization

Three role levels (enum-based):
- `operator` (0) - Basic access
- `production_manager` (1) - Elevated permissions
- `admin` (2) - Full access

Authorization logic in `authorized_orders` method:
- Admin: Access to all orders
- Manager/Operator: Only orders they created or are assigned to

**Note**: Pundit authorization is planned but currently uses basic case statements. Look for `TODO: Replace with Pundit` comments.

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

## Testing Patterns

### RSpec Configuration
- Uses transactional fixtures
- FactoryBot for test data
- Shoulda matchers for model validations
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

## Key Files

- `app/controllers/concerns/api/error_handling.rb` - Centralized error handling
- `app/controllers/api/v1/application_controller.rb` - Base API controller with auth and pagination helpers
- `app/models/production_order.rb` - Base STI model with auto-incrementing order numbers
