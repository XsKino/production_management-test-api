# API Documentation - Production Orders Management

Base URL: `http://localhost:3000/api/v1`

## Authentication

All endpoints (except login) require JWT authentication via the `Authorization` header:

```
Authorization: Bearer <jwt_token>
```

## Authorization & Roles

The API uses **Pundit** for granular authorization. There are three user roles with different permission levels:

### Role Hierarchy

1. **Admin (`admin`)** - Full access to all resources
2. **Production Manager (`production_manager`)** - Can manage orders and tasks they're assigned to or created
3. **Operator (`operator`)** - Read-only access to assigned orders, can only change task status

### Production Orders Permissions

| Action              | Admin        | Production Manager              | Operator             |
| ------------------- | ------------ | ------------------------------- | -------------------- |
| **View orders**     | All orders   | Assigned or created orders only | Assigned orders only |
| **Create order**    | ✅ Yes       | ✅ Yes                          | ❌ No                |
| **Update order**    | ✅ Any order | ✅ Assigned/created orders only | ❌ No                |
| **Delete order**    | ✅ Any order | ✅ Created orders only          | ❌ No                |
| **View statistics** | ✅ Yes       | ✅ Yes                          | ✅ Yes               |
| **View audit logs** | ✅ Any order | ✅ Assigned/created orders only | ✅ Assigned orders   |

### Tasks Permissions

| Action            | Admin        | Production Manager                    | Operator                      |
| ----------------- | ------------ | ------------------------------------- | ----------------------------- |
| **View tasks**    | All tasks    | Tasks from assigned/created orders    | Tasks from assigned orders    |
| **Create task**   | ✅ Any order | ✅ Assigned/created orders            | ❌ No                         |
| **Update task**   | ✅ Any task  | ✅ Tasks from assigned/created orders | ❌ No                         |
| **Delete task**   | ✅ Any task  | ✅ Tasks from assigned/created orders | ❌ No                         |
| **Complete task** | ✅ Any task  | ✅ Tasks from assigned/created orders | ✅ Tasks from assigned orders |
| **Reopen task**   | ✅ Any task  | ✅ Tasks from assigned/created orders | ✅ Tasks from assigned orders |

### Users Permissions

| Action          | Admin        | Production Manager  | Operator            |
| --------------- | ------------ | ------------------- | ------------------- |
| **View users**  | ✅ All users | ✅ All users        | ✅ All users        |
| **Create user** | ✅ Yes       | ❌ No               | ❌ No               |
| **Update user** | ✅ Any user  | ✅ Own profile only | ✅ Own profile only |
| **Delete user** | ✅ Yes       | ❌ No               | ❌ No               |

### Authorization Errors

When a user attempts an unauthorized action, the API returns:

**Response (403 Forbidden):**

```json
{
  "success": false,
  "message": "You are not authorized to perform this action",
  "code": "FORBIDDEN"
}
```

### POST /auth/login

Authenticate user and receive JWT token.

**Request:**

```json
POST /api/v1/auth/login
Content-Type: application/json

{
  "email": "user@example.com",
  "password": "password123"
}
```

**Response (200 OK):**

```json
{
  "success": true,
  "data": {
    "token": "eyJhbGciOiJIUzI1NiJ9...",
    "user": {
      "id": 1,
      "email": "user@example.com",
      "name": "John Doe",
      "role": "admin"
    }
  },
  "message": "Login successful"
}
```

**Error Response (401 Unauthorized):**

```json
{
  "success": false,
  "message": "Invalid email or password",
  "code": "INVALID_CREDENTIALS"
}
```

### POST /auth/logout

Logout current user (client should discard token).

**Request:**

```json
POST /api/v1/auth/logout
Authorization: Bearer <token>
```

**Response (200 OK):**

```json
{
  "success": true,
  "message": "Logged out successfully"
}
```

### POST /auth/refresh

Refresh JWT token to extend session.

**Request:**

```json
POST /api/v1/auth/refresh
Authorization: Bearer <token>
```

**Response (200 OK):**

```json
{
  "success": true,
  "data": {
    "token": "eyJhbGciOiJIUzI1NiJ9...",
    "user": {
      "id": 1,
      "email": "user@example.com",
      "name": "John Doe",
      "role": "admin"
    }
  },
  "message": "Token refreshed successfully"
}
```

**Error Response (401 Unauthorized):**

```json
{
  "success": false,
  "message": "Invalid token",
  "code": "INVALID_TOKEN"
}
```

---

## Production Orders

### GET /production_orders

List all production orders with pagination and filtering.

**Request:**

```
GET /api/v1/production_orders?page=1&per_page=20
Authorization: Bearer <token>
```

**Query Parameters:**

- `page` (integer, optional): Page number (default: 1)
- `per_page` (integer, optional): Items per page (default: 20, max: 100)
- `q[status_eq]` (string, optional): Filter by status (`pending`, `in_progress`, `completed`, `cancelled`)
- `q[type_eq]` (string, optional): Filter by type (`NormalOrder`, `UrgentOrder`)
- `q[start_date_gteq]` (date, optional): Filter by start date (greater than or equal)
- `q[start_date_lteq]` (date, optional): Filter by start date (less than or equal)
- `q[expected_end_date_gteq]` (date, optional): Filter by expected end date (greater than or equal)
- `q[expected_end_date_lteq]` (date, optional): Filter by expected end date (less than or equal)
- `q[creator_id_eq]` (integer, optional): Filter by creator ID
- `q[order_number_eq]` (string, optional): Filter by order number

**Response (200 OK):**

```json
{
  "success": true,
  "data": [
    {
      "id": 1,
      "type": "NormalOrder",
      "order_number": "NO-2025-001",
      "status": "pending",
      "start_date": "2025-01-15",
      "expected_end_date": "2025-01-30",
      "deadline": null,
      "created_at": "2025-01-10T10:00:00.000Z",
      "updated_at": "2025-01-10T10:00:00.000Z",
      "creator": {
        "id": 1,
        "name": "John Doe",
        "email": "john@example.com",
        "role": "admin"
      },
      "assigned_users": [
        {
          "id": 2,
          "name": "Jane Smith",
          "email": "jane@example.com",
          "role": "operator"
        }
      ],
      "tasks_count": 5,
      "completed_tasks_count": 2
    },
    {
      "id": 2,
      "type": "UrgentOrder",
      "order_number": "UO-2025-001",
      "status": "in_progress",
      "start_date": "2025-01-12",
      "expected_end_date": "2025-01-20",
      "deadline": "2025-01-18",
      "created_at": "2025-01-11T14:30:00.000Z",
      "updated_at": "2025-01-12T09:00:00.000Z",
      "creator": {
        "id": 1,
        "name": "John Doe",
        "email": "john@example.com",
        "role": "admin"
      },
      "assigned_users": [],
      "tasks_count": 3,
      "completed_tasks_count": 1
    }
  ],
  "meta": {
    "pagination": {
      "current_page": 1,
      "total_pages": 5,
      "total_count": 95,
      "per_page": 20,
      "has_next_page": true,
      "has_prev_page": false
    }
  }
}
```

### GET /production_orders/:id

Get details of a specific production order.

**Request:**

```
GET /api/v1/production_orders/1
Authorization: Bearer <token>
```

**Response (200 OK):**

```json
{
  "success": true,
  "data": {
    "id": 1,
    "type": "NormalOrder",
    "order_number": "NO-2025-001",
    "status": "pending",
    "start_date": "2025-01-15",
    "expected_end_date": "2025-01-30",
    "deadline": null,
    "created_at": "2025-01-10T10:00:00.000Z",
    "updated_at": "2025-01-10T10:00:00.000Z",
    "creator": {
      "id": 1,
      "name": "John Doe",
      "email": "john@example.com",
      "role": "admin"
    },
    "assigned_users": [
      {
        "id": 2,
        "name": "Jane Smith",
        "email": "jane@example.com",
        "role": "operator"
      }
    ],
    "tasks": [
      {
        "id": 1,
        "description": "Gather all required materials for production",
        "expected_end_date": "2025-01-16",
        "status": "completed",
        "production_order_id": 1,
        "created_at": "2025-01-10T10:00:00.000Z",
        "updated_at": "2025-01-16T15:30:00.000Z"
      },
      {
        "id": 2,
        "description": "Complete first assembly phase",
        "expected_end_date": "2025-01-20",
        "status": "pending",
        "production_order_id": 1,
        "created_at": "2025-01-10T10:00:00.000Z",
        "updated_at": "2025-01-10T10:00:00.000Z"
      }
    ]
  }
}
```

**Error Response (404 Not Found):**

```json
{
  "success": false,
  "message": "Production order not found",
  "code": "NOT_FOUND"
}
```

### POST /production_orders

Create a new production order (Normal or Urgent).

**Request for Normal Order:**

```json
POST /api/v1/production_orders
Authorization: Bearer <token>
Content-Type: application/json

{
  "production_order": {
    "type": "NormalOrder",
    "start_date": "2025-12-01",
    "expected_end_date": "2025-12-15",
    "tasks_attributes": [
      {
        "description": "First task description",
        "expected_end_date": "2025-12-05"
      },
      {
        "description": "Second task description",
        "expected_end_date": "2025-12-10"
      }
    ]
  },
  "user_ids": [2, 3]
}
```

**Request for Urgent Order:**

```json
POST /api/v1/production_orders
Authorization: Bearer <token>
Content-Type: application/json

{
  "production_order": {
    "type": "UrgentOrder",
    "start_date": "2025-12-01",
    "expected_end_date": "2025-12-08",
    "deadline": "2025-12-10",
    "tasks_attributes": [
      {
        "description": "Critical urgent task",
        "expected_end_date": "2025-12-05"
      }
    ]
  },
  "user_ids": [4, 5]
}
```

**Response (201 Created):**

```json
{
  "success": true,
  "data": {
    "id": 10,
    "type": "UrgentOrder",
    "order_number": "UO-2025-002",
    "status": "pending",
    "start_date": "2025-11-01",
    "expected_end_date": "2025-12-08",
    "deadline": "2025-12-10",
    "created_at": "2025-01-25T10:00:00.000Z",
    "updated_at": "2025-01-25T10:00:00.000Z",
    "creator": {
      "id": 1,
      "name": "John Doe",
      "email": "john@example.com",
      "role": "admin"
    },
    "assigned_users": [
      {
        "id": 2,
        "name": "Jane Smith",
        "email": "jane@example.com",
        "role": "operator"
      }
    ],
    "tasks": [
      {
        "id": 20,
        "description": "Critical urgent task",
        "expected_end_date": "2025-12-05",
        "status": "pending",
        "production_order_id": 10,
        "created_at": "2025-01-25T10:00:00.000Z",
        "updated_at": "2025-01-25T10:00:00.000Z"
      }
    ]
  },
  "message": "Production order created successfully"
}
```

**Error Response (422 Unprocessable Entity):**

```json
{
  "success": false,
  "message": "Validation failed",
  "errors": {
    "start_date": ["can't be blank"],
    "expected_end_date": ["can't be blank"]
  },
  "code": "VALIDATION_ERROR"
}
```

### PUT/PATCH /production_orders/:id

Update an existing production order.

**Request:**

```json
PATCH /api/v1/production_orders/1
Authorization: Bearer <token>
Content-Type: application/json

{
  "production_order": {
    "status": "in_progress",
    "expected_end_date": "2025-12-20"
  },
  "user_ids": [2, 3, 4]
}
```

**Response (200 OK):**

```json
{
  "success": true,
  "data": {
    "id": 1,
    "type": "NormalOrder",
    "order_number": "NO-2025-001",
    "status": "in_progress",
    "start_date": "2025-01-15",
    "expected_end_date": "2025-12-20",
    "deadline": null,
    "created_at": "2025-01-10T10:00:00.000Z",
    "updated_at": "2025-01-25T11:00:00.000Z",
    "creator": {
      "id": 1,
      "name": "John Doe",
      "email": "john@example.com",
      "role": "admin"
    },
    "assigned_users": [
      {
        "id": 2,
        "name": "Jane Smith",
        "email": "jane@example.com",
        "role": "operator"
      },
      {
        "id": 3,
        "name": "Bob Johnson",
        "email": "bob@example.com",
        "role": "operator"
      },
      {
        "id": 4,
        "name": "Alice Williams",
        "email": "alice@example.com",
        "role": "production_manager"
      }
    ],
    "tasks": []
  },
  "message": "Production order updated successfully"
}
```

### DELETE /production_orders/:id

Delete a production order.

**Request:**

```
DELETE /api/v1/production_orders/1
Authorization: Bearer <token>
```

**Response (200 OK):**

```json
{
  "success": true,
  "message": "Production order deleted successfully"
}
```

### GET /production_orders/:id/tasks_summary

Get summary of tasks for a specific production order.

**Request:**

```
GET /api/v1/production_orders/1/tasks_summary
Authorization: Bearer <token>
```

**Response (200 OK):**

```json
{
  "success": true,
  "data": {
    "order_id": 1,
    "order_number": "NO-2025-001",
    "total_tasks": 5,
    "completed_tasks": 2,
    "pending_tasks": 3,
    "completion_percentage": 40.0,
    "overdue_tasks": 1
  }
}
```

---

### GET /production_orders/:id/audit_logs

Get audit logs for a specific production order. Shows all changes made to the order including who made the change, when, and what changed.

**Authorization:** Admin can view any order's logs. Production Managers can view logs for orders they created or are assigned to. Operators can view logs for orders they're assigned to.

**Request:**

```
GET /api/v1/production_orders/1/audit_logs
Authorization: Bearer <token>
```

**Query Parameters:**

- `page` (optional): Page number for pagination (default: 1)
- `per_page` (optional): Items per page (default: 20, max: 100)

**Response (200 OK):**

```json
{
  "success": true,
  "data": [
    {
      "id": 15,
      "action": "status_changed",
      "change_details": {
        "status": {
          "from": "pending",
          "to": "completed"
        }
      },
      "user": {
        "id": 2,
        "name": "John Manager",
        "email": "manager@example.com"
      },
      "ip_address": "192.168.1.100",
      "user_agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)",
      "created_at": "2025-01-15T10:30:00.000Z"
    },
    {
      "id": 12,
      "action": "type_changed",
      "change_details": {
        "type": {
          "from": "NormalOrder",
          "to": "UrgentOrder"
        },
        "order_number": {
          "from": 1,
          "to": 2
        }
      },
      "user": {
        "id": 1,
        "name": "Admin User",
        "email": "admin@example.com"
      },
      "ip_address": "192.168.1.50",
      "user_agent": "PostmanRuntime/7.32.0",
      "created_at": "2025-01-14T14:20:00.000Z"
    },
    {
      "id": 8,
      "action": "created",
      "change_details": {
        "order_number": 1,
        "type": "NormalOrder",
        "status": "pending",
        "start_date": "2025-01-10",
        "expected_end_date": "2025-01-20"
      },
      "user": {
        "id": 2,
        "name": "John Manager",
        "email": "manager@example.com"
      },
      "ip_address": "192.168.1.100",
      "user_agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)",
      "created_at": "2025-01-10T09:00:00.000Z"
    }
  ],
  "meta": {
    "pagination": {
      "current_page": 1,
      "total_pages": 2,
      "total_count": 25,
      "per_page": 20,
      "has_next_page": true,
      "has_prev_page": false
    }
  }
}
```

**Available Actions:**

- `created` - Order was created
- `updated` - General update to order fields
- `deleted` - Order was deleted
- `status_changed` - Order status was changed
- `type_changed` - Order type was changed (NormalOrder ↔ UrgentOrder)
- `assigned` - User was assigned to order
- `unassigned` - User was unassigned from order
- `task_added` - Task was added to order
- `task_updated` - Task was updated
- `task_deleted` - Task was deleted

**Response (403 Forbidden):**

```json
{
  "success": false,
  "error": {
    "code": "FORBIDDEN",
    "message": "You are not authorized to perform this action"
  }
}
```

**Response (404 Not Found):**

```json
{
  "success": false,
  "error": {
    "code": "NOT_FOUND",
    "message": "Resource not found"
  }
}
```

---

## Report Endpoints

### GET /production_orders/urgent_orders_report

Get report of all urgent orders with their status.

**Request:**

```
GET /api/v1/production_orders/urgent_orders_report
Authorization: Bearer <token>
```

**Response (200 OK):**

```json
{
  "success": true,
  "data": {
    "total_urgent_orders": 15,
    "by_status": {
      "pending": 5,
      "in_progress": 7,
      "completed": 2,
      "cancelled": 1
    },
    "orders": [
      {
        "id": 2,
        "order_number": "UO-2025-001",
        "status": "in_progress",
        "deadline": "2025-01-18",
        "days_until_deadline": 3,
        "is_overdue": false,
        "completion_percentage": 33.33
      }
    ]
  }
}
```

### GET /production_orders/monthly_statistics

Get monthly statistics for production orders.

**Request:**

```
GET /api/v1/production_orders/monthly_statistics?year=2025&month=1
Authorization: Bearer <token>
```

**Query Parameters:**

- `year` (integer, optional): Year (default: current year)
- `month` (integer, optional): Month (1-12, default: current month)

**Response (200 OK):**

```json
{
  "success": true,
  "data": {
    "period": "January 2025",
    "total_orders": 25,
    "normal_orders": 18,
    "urgent_orders": 7,
    "by_status": {
      "pending": 8,
      "in_progress": 10,
      "completed": 6,
      "cancelled": 1
    },
    "completion_rate": 24.0,
    "average_completion_time_days": 12.5,
    "orders_created": 25,
    "orders_completed": 6,
    "total_tasks": 125,
    "completed_tasks": 45,
    "task_completion_rate": 36.0
  }
}
```

### GET /production_orders/urgent_with_expired_tasks

Get urgent orders that have expired tasks.

**Request:**

```
GET /api/v1/production_orders/urgent_with_expired_tasks
Authorization: Bearer <token>
```

**Response (200 OK):**

```json
{
  "success": true,
  "data": {
    "total_orders_with_expired_tasks": 3,
    "orders": [
      {
        "id": 2,
        "order_number": "UO-2025-001",
        "status": "in_progress",
        "deadline": "2025-01-18",
        "days_until_deadline": -2,
        "is_overdue": true,
        "expired_tasks": [
          {
            "id": 5,
            "description": "Critical assembly task",
            "expected_end_date": "2025-01-15",
            "days_overdue": 10,
            "status": "pending"
          }
        ]
      }
    ]
  }
}
```

---

## Tasks

Tasks are managed as nested resources under production orders. Tasks only have:

- **description**: Text description of the task
- **expected_end_date**: Date when the task should be completed
- **status**: Either `pending` or `completed`

Tasks do NOT have individual user assignments - users are assigned to the entire production order.

### POST /production_orders/:production_order_id/tasks

Create a new task for a production order.

**Request:**

```json
POST /api/v1/production_orders/1/tasks
Authorization: Bearer <token>
Content-Type: application/json

{
  "task": {
    "description": "Perform quality check on all units",
    "expected_end_date": "2025-12-10",
    "status": "pending"
  }
}
```

**Response (201 Created):**

```json
{
  "success": true,
  "data": {
    "id": 25,
    "description": "Perform quality check on all units",
    "expected_end_date": "2025-12-10",
    "status": "pending",
    "production_order_id": 1,
    "created_at": "2025-01-25T12:00:00.000Z",
    "updated_at": "2025-01-25T12:00:00.000Z"
  },
  "message": "Task created successfully"
}
```

### PUT/PATCH /production_orders/:production_order_id/tasks/:id

Update an existing task.

**Request:**

```json
PATCH /api/v1/production_orders/1/tasks/25
Authorization: Bearer <token>
Content-Type: application/json

{
  "task": {
    "description": "Perform detailed quality check on all units",
    "expected_end_date": "2025-12-12"
  }
}
```

**Response (200 OK):**

```json
{
  "success": true,
  "data": {
    "id": 25,
    "description": "Perform detailed quality check on all units",
    "expected_end_date": "2025-12-12",
    "status": "pending",
    "production_order_id": 1,
    "created_at": "2025-01-25T12:00:00.000Z",
    "updated_at": "2025-01-25T12:30:00.000Z"
  },
  "message": "Task updated successfully"
}
```

### DELETE /production_orders/:production_order_id/tasks/:id

Delete a task.

**Request:**

```
DELETE /api/v1/production_orders/1/tasks/25
Authorization: Bearer <token>
```

**Response (200 OK):**

```json
{
  "success": true,
  "message": "Task deleted successfully"
}
```

### PATCH /production_orders/:production_order_id/tasks/:id/complete

Mark a task as completed.

**Request:**

```
PATCH /api/v1/production_orders/1/tasks/25/complete
Authorization: Bearer <token>
```

**Response (200 OK):**

```json
{
  "success": true,
  "data": {
    "id": 25,
    "description": "Perform quality check on all units",
    "expected_end_date": "2025-12-10",
    "status": "completed",
    "production_order_id": 1,
    "created_at": "2025-01-25T12:00:00.000Z",
    "updated_at": "2025-01-25T14:30:00.000Z"
  },
  "message": "Task completed successfully"
}
```

### PATCH /production_orders/:production_order_id/tasks/:id/reopen

Reopen a completed task.

**Request:**

```
PATCH /api/v1/production_orders/1/tasks/25/reopen
Authorization: Bearer <token>
```

**Response (200 OK):**

```json
{
  "success": true,
  "data": {
    "id": 25,
    "description": "Perform quality check on all units",
    "expected_end_date": "2025-12-10",
    "status": "pending",
    "production_order_id": 1,
    "created_at": "2025-01-25T12:00:00.000Z",
    "updated_at": "2025-01-25T15:00:00.000Z"
  },
  "message": "Task reopened successfully"
}
```

---

## Order Assignments

Manage user assignments to production orders.

### POST /order_assignments

Assign a user to a production order.

**Request:**

```json
POST /api/v1/order_assignments
Authorization: Bearer <token>
Content-Type: application/json

{
  "order_assignment": {
    "production_order_id": 1,
    "user_id": 3
  }
}
```

**Response (201 Created):**

```json
{
  "success": true,
  "data": {
    "id": 15,
    "production_order_id": 1,
    "user_id": 3,
    "assigned_at": "2025-01-25T16:00:00.000Z"
  },
  "message": "User assigned to order successfully"
}
```

**Error Response (422 Unprocessable Entity):**

```json
{
  "success": false,
  "message": "User has already been assigned to this order",
  "code": "VALIDATION_ERROR"
}
```

### DELETE /order_assignments/:id

Remove a user assignment from a production order.

**Request:**

```
DELETE /api/v1/order_assignments/15
Authorization: Bearer <token>
```

**Response (200 OK):**

```json
{
  "success": true,
  "message": "User unassigned from order successfully"
}
```

---

## Users

Manage system users.

### GET /users

List all users with pagination.

**Request:**

```
GET /api/v1/users?page=1&per_page=20
Authorization: Bearer <token>
```

**Query Parameters:**

- `page` (integer, optional): Page number (default: 1)
- `per_page` (integer, optional): Items per page (default: 20, max: 100)

**Response (200 OK):**

```json
{
  "success": true,
  "data": [
    {
      "id": 1,
      "email": "john@example.com",
      "name": "John Doe",
      "role": "admin",
      "created_at": "2025-01-01T10:00:00.000Z",
      "updated_at": "2025-01-01T10:00:00.000Z"
    },
    {
      "id": 2,
      "email": "jane@example.com",
      "name": "Jane Smith",
      "role": "operator",
      "created_at": "2025-01-02T11:00:00.000Z",
      "updated_at": "2025-01-02T11:00:00.000Z"
    }
  ],
  "meta": {
    "pagination": {
      "current_page": 1,
      "total_pages": 3,
      "total_count": 45,
      "per_page": 20,
      "has_next_page": true,
      "has_prev_page": false
    }
  }
}
```

### GET /users/:id

Get details of a specific user.

**Request:**

```
GET /api/v1/users/1
Authorization: Bearer <token>
```

**Response (200 OK):**

```json
{
  "success": true,
  "data": {
    "id": 1,
    "email": "john@example.com",
    "name": "John Doe",
    "role": "admin",
    "created_at": "2025-01-01T10:00:00.000Z",
    "updated_at": "2025-01-01T10:00:00.000Z"
  }
}
```

### POST /users

Create a new user.

**Request:**

```json
POST /api/v1/users
Authorization: Bearer <token>
Content-Type: application/json

{
  "user": {
    "email": "newuser@example.com",
    "name": "New User",
    "password": "securepassword123",
    "role": "operator"
  }
}
```

**Response (201 Created):**

```json
{
  "success": true,
  "data": {
    "id": 50,
    "email": "newuser@example.com",
    "name": "New User",
    "role": "operator",
    "created_at": "2025-01-25T17:00:00.000Z",
    "updated_at": "2025-01-25T17:00:00.000Z"
  },
  "message": "User created successfully"
}
```

### PUT/PATCH /users/:id

Update an existing user.

**Request:**

```json
PATCH /api/v1/users/50
Authorization: Bearer <token>
Content-Type: application/json

{
  "user": {
    "name": "Updated Name",
    "role": "production_manager"
  }
}
```

**Response (200 OK):**

```json
{
  "success": true,
  "data": {
    "id": 50,
    "email": "newuser@example.com",
    "name": "Updated Name",
    "role": "production_manager",
    "created_at": "2025-01-25T17:00:00.000Z",
    "updated_at": "2025-01-25T17:30:00.000Z"
  },
  "message": "User updated successfully"
}
```

### DELETE /users/:id

Delete a user.

**Request:**

```
DELETE /api/v1/users/50
Authorization: Bearer <token>
```

**Response (200 OK):**

```json
{
  "success": true,
  "message": "User deleted successfully"
}
```

---

## Health Check

### GET /health

Check API health status.

**Request:**

```
GET /api/v1/health
```

**Response (200 OK):**

```json
{
  "status": "ok",
  "timestamp": "2025-01-25T18:00:00.000Z",
  "version": "1.0.0"
}
```

---

## User Roles

The system supports the following user roles:

- **admin**: Full system access, can manage all resources
- **production_manager**: Can manage production orders and tasks, view reports
- **operator**: Can view assigned orders and update task status

---

## Error Codes

Common error codes returned by the API:

- `UNAUTHORIZED`: Missing or invalid authentication token
- `FORBIDDEN`: User doesn't have permission for this action
- `NOT_FOUND`: Requested resource not found
- `VALIDATION_ERROR`: Request data failed validation
- `INVALID_CREDENTIALS`: Invalid email or password (login)
- `INVALID_TOKEN`: Token is invalid or expired (refresh)
- `USER_NOT_FOUND`: User associated with token not found

---

## Common Error Responses

**401 Unauthorized:**

```json
{
  "success": false,
  "message": "Unauthorized",
  "code": "UNAUTHORIZED"
}
```

**403 Forbidden:**

```json
{
  "success": false,
  "message": "You are not authorized to perform this action",
  "code": "FORBIDDEN"
}
```

**404 Not Found:**

```json
{
  "success": false,
  "message": "Resource not found",
  "code": "NOT_FOUND"
}
```

**422 Validation Error:**

```json
{
  "success": false,
  "message": "Validation failed",
  "errors": {
    "field_name": ["error message 1", "error message 2"]
  },
  "code": "VALIDATION_ERROR"
}
```

**500 Internal Server Error:**

```json
{
  "success": false,
  "message": "Internal server error",
  "code": "INTERNAL_ERROR"
}
```

---

## Notes

- All timestamps are in ISO 8601 format (UTC)
- Dates are in YYYY-MM-DD format
- JWT tokens expire after 24 hours
- All requests must include `Content-Type: application/json` header for POST/PUT/PATCH requests
- Order numbers are automatically generated with format: `NO-YYYY-XXX` (NormalOrder) or `UO-YYYY-XXX` (UrgentOrder)
- **Audit Logging**: All changes to production orders are automatically tracked with user information, IP address, and timestamp. Audit logs are preserved even when orders are deleted.
- Pagination defaults to 20 items per page, maximum 100 items per page
