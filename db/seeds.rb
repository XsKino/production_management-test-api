# Seeds for Production Orders Management System
# This simulates a system that has been running for several weeks

# Clear existing data
puts "🧹 Cleaning existing data..."
OrderAuditLog.destroy_all
Task.destroy_all
OrderAssignment.destroy_all
ProductionOrder.destroy_all
User.destroy_all

# Helper to create audit log manually (bypassing callbacks)
def create_audit_log(order, user, action, change_details, created_at)
  OrderAuditLog.create!(
    production_order: order,
    user: user,
    action: action,
    change_details: change_details,
    ip_address: ['192.168.1.100', '192.168.1.101', '192.168.1.102'].sample,
    user_agent: 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)',
    created_at: created_at,
    updated_at: created_at
  )
end

puts "👥 Creating users..."

# Create admins (2)
admins = [
  User.create!(
    name: 'Carlos Rodríguez',
    email: 'carlos.rodriguez@empresa.com',
    password: 'password123',
    role: :admin
  ),
  User.create!(
    name: 'María González',
    email: 'maria.gonzalez@empresa.com',
    password: 'password123',
    role: :admin
  )
]

# Create production managers (5)
managers = [
  User.create!(name: 'Roberto Silva', email: 'roberto.silva@empresa.com', password: 'password123', role: :production_manager),
  User.create!(name: 'Ana Martínez', email: 'ana.martinez@empresa.com', password: 'password123', role: :production_manager),
  User.create!(name: 'Luis Fernández', email: 'luis.fernandez@empresa.com', password: 'password123', role: :production_manager),
  User.create!(name: 'Patricia Gómez', email: 'patricia.gomez@empresa.com', password: 'password123', role: :production_manager),
  User.create!(name: 'Jorge Ramírez', email: 'jorge.ramirez@empresa.com', password: 'password123', role: :production_manager)
]

# Create operators (8)
operators = [
  User.create!(name: 'Miguel Torres', email: 'miguel.torres@empresa.com', password: 'password123', role: :operator),
  User.create!(name: 'Laura Díaz', email: 'laura.diaz@empresa.com', password: 'password123', role: :operator),
  User.create!(name: 'Pedro Sánchez', email: 'pedro.sanchez@empresa.com', password: 'password123', role: :operator),
  User.create!(name: 'Carmen López', email: 'carmen.lopez@empresa.com', password: 'password123', role: :operator),
  User.create!(name: 'José Hernández', email: 'jose.hernandez@empresa.com', password: 'password123', role: :operator),
  User.create!(name: 'Elena Jiménez', email: 'elena.jimenez@empresa.com', password: 'password123', role: :operator),
  User.create!(name: 'Ricardo Morales', email: 'ricardo.morales@empresa.com', password: 'password123', role: :operator),
  User.create!(name: 'Sofía Castro', email: 'sofia.castro@empresa.com', password: 'password123', role: :operator)
]

puts "✅ Created #{User.count} users (2 admins, 5 managers, 8 operators)"

# Timeline: System has been running for 4 weeks
today = Date.current
four_weeks_ago = today - 28.days

puts "\n📦 Creating production orders over 4-week period..."

orders = []
all_users = admins + managers

# Week 1 (4 weeks ago): System just starting
(four_weeks_ago..four_weeks_ago + 6.days).each do |date|
  # 1-2 orders per day
  rand(1..2).times do
    creator = all_users.sample
    is_urgent = rand < 0.3 # 30% urgent orders

    start_date = date
    expected_end_date = start_date + rand(5..15).days

    order = if is_urgent
      UrgentOrder.create!(
        creator: creator,
        start_date: start_date,
        expected_end_date: expected_end_date,
        deadline: expected_end_date - rand(1..3).days,
        status: :pending,
        created_at: start_date.to_time + rand(8..17).hours,
        updated_at: start_date.to_time + rand(8..17).hours
      )
    else
      NormalOrder.create!(
        creator: creator,
        start_date: start_date,
        expected_end_date: expected_end_date,
        status: :pending,
        created_at: start_date.to_time + rand(8..17).hours,
        updated_at: start_date.to_time + rand(8..17).hours
      )
    end

    orders << order

    # Assign 2-3 operators
    assigned_operators = operators.sample(rand(2..3))
    assigned_operators.each do |operator|
      OrderAssignment.create!(
        production_order: order,
        user: operator,
        created_at: order.created_at + rand(1..30).minutes,
        updated_at: order.created_at + rand(1..30).minutes
      )
    end

    # Create audit log for creation
    create_audit_log(order, creator, 'created', order.attributes.except('id', 'created_at', 'updated_at'), order.created_at)

    # Create audit logs for assignments
    assigned_operators.each do |operator|
      create_audit_log(
        order,
        creator,
        'assigned',
        { user_id: operator.id, user_name: operator.name },
        order.created_at + rand(1..30).minutes
      )
    end
  end
end

puts "✅ Week 1: Created #{orders.count} orders"

# Week 2 (3 weeks ago): More activity, some orders completing
week2_start = four_weeks_ago + 7.days
(week2_start..week2_start + 6.days).each do |date|
  # 2-3 orders per day
  rand(2..3).times do
    creator = all_users.sample
    is_urgent = rand < 0.35

    start_date = date
    expected_end_date = start_date + rand(5..15).days

    order = if is_urgent
      UrgentOrder.create!(
        creator: creator,
        start_date: start_date,
        expected_end_date: expected_end_date,
        deadline: expected_end_date - rand(1..3).days,
        status: :pending,
        created_at: start_date.to_time + rand(8..17).hours,
        updated_at: start_date.to_time + rand(8..17).hours
      )
    else
      NormalOrder.create!(
        creator: creator,
        start_date: start_date,
        expected_end_date: expected_end_date,
        status: :pending,
        created_at: start_date.to_time + rand(8..17).hours,
        updated_at: start_date.to_time + rand(8..17).hours
      )
    end

    orders << order

    assigned_operators = operators.sample(rand(2..3))
    assigned_operators.each do |operator|
      OrderAssignment.create!(
        production_order: order,
        user: operator,
        created_at: order.created_at + rand(1..30).minutes,
        updated_at: order.created_at + rand(1..30).minutes
      )
    end

    create_audit_log(order, creator, 'created', order.attributes.except('id', 'created_at', 'updated_at'), order.created_at)

    assigned_operators.each do |operator|
      create_audit_log(order, creator, 'assigned', { user_id: operator.id, user_name: operator.name }, order.created_at + rand(1..30).minutes)
    end
  end
end

# Complete some old orders from week 1
orders_to_complete = orders.first(5)
orders_to_complete.each do |order|
  completion_date = week2_start + rand(0..6).days + rand(10..16).hours
  order.update_columns(status: :completed, updated_at: completion_date)
  create_audit_log(
    order,
    managers.sample,
    'status_changed',
    { status: { from: 'pending', to: 'completed' } },
    completion_date
  )
end

puts "✅ Week 2: Created #{orders.count - orders_to_complete.count} orders, completed 5 old orders"

# Week 3 (2 weeks ago): System in full operation
week3_start = four_weeks_ago + 14.days
week3_orders_start = orders.count
(week3_start..week3_start + 6.days).each do |date|
  # 3-4 orders per day (peak activity)
  rand(3..4).times do
    creator = all_users.sample
    is_urgent = rand < 0.4

    start_date = date
    expected_end_date = start_date + rand(5..15).days

    order = if is_urgent
      UrgentOrder.create!(
        creator: creator,
        start_date: start_date,
        expected_end_date: expected_end_date,
        deadline: expected_end_date - rand(1..3).days,
        status: :pending,
        created_at: start_date.to_time + rand(8..17).hours,
        updated_at: start_date.to_time + rand(8..17).hours
      )
    else
      NormalOrder.create!(
        creator: creator,
        start_date: start_date,
        expected_end_date: expected_end_date,
        status: :pending,
        created_at: start_date.to_time + rand(8..17).hours,
        updated_at: start_date.to_time + rand(8..17).hours
      )
    end

    orders << order

    assigned_operators = operators.sample(rand(2..4))
    assigned_operators.each do |operator|
      OrderAssignment.create!(
        production_order: order,
        user: operator,
        created_at: order.created_at + rand(1..30).minutes,
        updated_at: order.created_at + rand(1..30).minutes
      )
    end

    create_audit_log(order, creator, 'created', order.attributes.except('id', 'created_at', 'updated_at'), order.created_at)

    assigned_operators.each do |operator|
      create_audit_log(order, creator, 'assigned', { user_id: operator.id, user_name: operator.name }, order.created_at + rand(1..30).minutes)
    end
  end
end

# Complete more orders
orders_to_complete = orders[5..15]
orders_to_complete.each do |order|
  completion_date = week3_start + rand(0..6).days + rand(10..16).hours
  order.update_columns(status: :completed, updated_at: completion_date)
  create_audit_log(order, managers.sample, 'status_changed', { status: { from: 'pending', to: 'completed' } }, completion_date)
end

# Cancel 1-2 orders
orders_to_cancel = orders[16..17]
orders_to_cancel.each do |order|
  cancellation_date = week3_start + rand(0..6).days + rand(10..16).hours
  order.update_columns(status: :cancelled, updated_at: cancellation_date)
  create_audit_log(order, admins.sample, 'status_changed', { status: { from: 'pending', to: 'cancelled' } }, cancellation_date)
end

puts "✅ Week 3: Created #{orders.count - week3_orders_start} orders, completed 11 orders, cancelled 2"

# Week 4 (last week): Current operations
week4_start = four_weeks_ago + 21.days
week4_orders_start = orders.count
(week4_start..today).each do |date|
  # 2-3 orders per day
  rand(2..3).times do
    creator = all_users.sample
    is_urgent = rand < 0.35

    start_date = date
    expected_end_date = start_date + rand(5..15).days

    order = if is_urgent
      UrgentOrder.create!(
        creator: creator,
        start_date: start_date,
        expected_end_date: expected_end_date,
        deadline: expected_end_date - rand(1..3).days,
        status: :pending,
        created_at: start_date.to_time + rand(8..17).hours,
        updated_at: start_date.to_time + rand(8..17).hours
      )
    else
      NormalOrder.create!(
        creator: creator,
        start_date: start_date,
        expected_end_date: expected_end_date,
        status: :pending,
        created_at: start_date.to_time + rand(8..17).hours,
        updated_at: start_date.to_time + rand(8..17).hours
      )
    end

    orders << order

    assigned_operators = operators.sample(rand(2..3))
    assigned_operators.each do |operator|
      OrderAssignment.create!(
        production_order: order,
        user: operator,
        created_at: order.created_at + rand(1..30).minutes,
        updated_at: order.created_at + rand(1..30).minutes
      )
    end

    create_audit_log(order, creator, 'created', order.attributes.except('id', 'created_at', 'updated_at'), order.created_at)

    assigned_operators.each do |operator|
      create_audit_log(order, creator, 'assigned', { user_id: operator.id, user_name: operator.name }, order.created_at + rand(1..30).minutes)
    end
  end
end

# Complete some recent orders
orders_to_complete = orders[18..25]
orders_to_complete&.each do |order|
  if order.created_at < 3.days.ago
    completion_date = order.created_at + rand(2..5).days + rand(10..16).hours
    order.update_columns(status: :completed, updated_at: completion_date)
    create_audit_log(order, managers.sample, 'status_changed', { status: { from: 'pending', to: 'completed' } }, completion_date)
  end
end

puts "✅ Week 4: Created #{orders.count - week4_orders_start} orders"
puts "📦 Total orders created: #{orders.count}"

# Now create tasks for all orders
puts "\n📋 Creating tasks for all orders..."

task_descriptions = [
  'Preparación de materiales',
  'Corte de piezas',
  'Ensamblaje inicial',
  'Soldadura de componentes',
  'Pintura y acabado',
  'Control de calidad',
  'Empaquetado',
  'Revisión final',
  'Preparación de documentación',
  'Inspección de seguridad',
  'Calibración de equipos',
  'Pruebas de funcionamiento',
  'Ajustes finales',
  'Limpieza y mantenimiento'
]

total_tasks = 0
orders.each do |order|
  # Each order has 3-6 tasks
  num_tasks = rand(3..6)
  order_duration = (order.expected_end_date - order.start_date).to_i

  num_tasks.times do |i|
    # Tasks are distributed throughout the order timeline
    task_start = order.start_date + (order_duration * i / num_tasks).days
    task_end = task_start + rand(1..3).days

    # Determine task status based on order status and dates
    task_status = if order.completed?
      :completed
    elsif order.cancelled?
      rand < 0.7 ? :pending : :completed # Some tasks might be done before cancellation
    elsif task_end < today
      # Task is expired but order still pending
      rand < 0.6 ? :completed : :pending # 60% completed, 40% expired
    elsif task_start <= today
      # Task should be in progress or recently completed
      rand < 0.5 ? :completed : :pending
    else
      :pending # Future task
    end

    task = Task.create!(
      production_order: order,
      description: task_descriptions.sample,
      expected_end_date: task_end,
      status: task_status,
      created_at: order.created_at + rand(1..60).minutes,
      updated_at: order.created_at + rand(1..60).minutes
    )

    total_tasks += 1

    # Create audit log for task creation
    create_audit_log(
      order,
      order.creator,
      'task_added',
      { task_id: task.id, description: task.description },
      task.created_at
    )

    # If task was completed, create completion audit log
    if task.completed?
      completion_time = [task.expected_end_date, order.updated_at].min.to_time + rand(10..16).hours
      create_audit_log(
        order,
        order.assigned_users.sample || order.creator,
        'task_updated',
        { task_id: task.id, status: { from: 'pending', to: 'completed' } },
        completion_time
      )
    end
  end
end

puts "✅ Created #{total_tasks} tasks"

# Create some realistic updates and modifications
puts "\n📝 Creating order updates and modifications..."

# Some orders had their dates adjusted
orders_to_update = orders.select(&:pending?).sample(5)
orders_to_update.each do |order|
  update_time = order.created_at + rand(1..7).days + rand(9..17).hours
  old_end_date = order.expected_end_date
  new_end_date = old_end_date + rand(2..5).days

  order.update_columns(expected_end_date: new_end_date, updated_at: update_time)

  create_audit_log(
    order,
    managers.sample,
    'updated',
    { expected_end_date: { from: old_end_date, to: new_end_date } },
    update_time
  )
end

puts "✅ Updated 5 orders with date modifications"

# Some urgent orders had deadline changes
urgent_orders_to_update = orders.select { |o| o.is_a?(UrgentOrder) && o.pending? }.sample(3)
urgent_orders_to_update.each do |order|
  update_time = order.created_at + rand(1..5).days + rand(9..17).hours
  old_deadline = order.deadline
  new_deadline = old_deadline + rand(1..3).days

  order.update_columns(deadline: new_deadline, updated_at: update_time)

  create_audit_log(
    order,
    admins.sample,
    'updated',
    { deadline: { from: old_deadline, to: new_deadline } },
    update_time
  )
end

puts "✅ Updated 3 urgent orders with deadline extensions"

# Some orders had operators reassigned
orders_to_reassign = orders.select(&:pending?).sample(4)
orders_to_reassign.each do |order|
  reassign_time = order.created_at + rand(1..10).days + rand(9..17).hours

  # Remove one operator
  old_operator = order.assigned_users.sample
  if old_operator
    order.order_assignments.find_by(user: old_operator)&.destroy
    create_audit_log(
      order,
      managers.sample,
      'unassigned',
      { user_id: old_operator.id, user_name: old_operator.name },
      reassign_time
    )
  end

  # Add new operator
  new_operator = (operators - order.assigned_users).sample
  if new_operator
    OrderAssignment.create!(
      production_order: order,
      user: new_operator,
      created_at: reassign_time + 5.minutes,
      updated_at: reassign_time + 5.minutes
    )
    create_audit_log(
      order,
      managers.sample,
      'assigned',
      { user_id: new_operator.id, user_name: new_operator.name },
      reassign_time + 5.minutes
    )
  end
end

puts "✅ Reassigned operators on 4 orders"

# Print summary statistics
puts "\n" + "="*60
puts "📊 SEED DATA SUMMARY"
puts "="*60

puts "\n👥 Users:"
puts "  - Admins: #{User.where(role: :admin).count}"
puts "  - Production Managers: #{User.where(role: :production_manager).count}"
puts "  - Operators: #{User.where(role: :operator).count}"
puts "  - Total: #{User.count}"

puts "\n📦 Production Orders:"
puts "  - Normal Orders: #{NormalOrder.count}"
puts "  - Urgent Orders: #{UrgentOrder.count}"
puts "  - Total: #{ProductionOrder.count}"

puts "\n📊 Orders by Status:"
puts "  - Pending: #{ProductionOrder.where(status: :pending).count}"
puts "  - Completed: #{ProductionOrder.where(status: :completed).count}"
puts "  - Cancelled: #{ProductionOrder.where(status: :cancelled).count}"

puts "\n📋 Tasks:"
puts "  - Pending: #{Task.where(status: :pending).count}"
puts "  - Completed: #{Task.where(status: :completed).count}"
puts "  - Total: #{Task.count}"

expired_tasks = Task.where(status: :pending).where('expected_end_date < ?', Date.current).count
puts "  - ⚠️  Expired (pending past deadline): #{expired_tasks}"

puts "\n🔗 Order Assignments: #{OrderAssignment.count}"
puts "📝 Audit Logs: #{OrderAuditLog.count}"

puts "\n⏰ Date Range:"
puts "  - Oldest order: #{ProductionOrder.order(:created_at).first&.created_at&.to_date}"
puts "  - Newest order: #{ProductionOrder.order(:created_at).last&.created_at&.to_date}"

urgent_with_expired = UrgentOrder.joins(:tasks)
                                  .where(status: :pending)
                                  .where('tasks.status = ? AND tasks.expected_end_date < ?',
                                         Task.statuses[:pending], Date.current)
                                  .distinct
                                  .count

puts "\n⚠️  Alerts:"
puts "  - Urgent orders with expired tasks: #{urgent_with_expired}"
puts "  - Orders needing attention: #{ProductionOrder.where(status: :pending).where('expected_end_date < ?', Date.current + 3.days).count}"

puts "\n✅ Seed data created successfully!"
puts "="*60
