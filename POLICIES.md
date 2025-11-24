# Policy Files Reference

The authorization system is implemented using [Pundit](https://github.com/varvet/pundit) with the following policy files:

## Core Policies

**app/policies/application_policy.rb**

- Base policy class that all other policies inherit from
- Provides default deny-all behavior for all actions
- Defines the basic policy structure and Scope class

**app/policies/production_order_policy.rb**

- Main policy for ProductionOrder authorization
- Defines permissions for: index, show, create, update, destroy, tasks_summary
- Defines report permissions: monthly_statistics, urgent_orders_report, urgent_with_expired_tasks
- Implements scope filtering so users only see orders they're authorized to access
- Admin: can access all orders
- Production Manager: can access orders they created or are assigned to
- Operator: can only view orders they're assigned to (read-only)

**app/policies/normal_order_policy.rb**

- Policy for NormalOrder (STI subclass)
- Inherits all behavior from ProductionOrderPolicy
- Required for Pundit to properly authorize NormalOrder instances

**app/policies/urgent_order_policy.rb**

- Policy for UrgentOrder (STI subclass)
- Inherits all behavior from ProductionOrderPolicy
- Required for Pundit to properly authorize UrgentOrder instances

**app/policies/task_policy.rb**

- Policy for Task authorization
- Defines permissions for: index, show, create, update, destroy, complete, reopen
- Implements scope filtering based on production order assignments
- Admin: full control over all tasks
- Production Manager: full control over tasks in orders they created or are assigned to
- Operator: can only view and change status (complete/reopen) of tasks in assigned orders

**app/policies/user_policy.rb**

- Policy for User management
- Defines permissions for: index, show, create, update, destroy
- Everyone can view all users (index and show)
- Users can update their own profile
- Only admins can create and delete users

## Policy Scopes

Each policy implements a `Scope` class that automatically filters collections based on user permissions. This ensures that when querying `ProductionOrder.all` or `Task.all`, users only see records they're authorized to access.

For more details on how authorization works, see the [Authorization & Roles](#authorization--roles) section above.
