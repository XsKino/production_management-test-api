# Script para crear datos de prueba para los cron jobs
# Ejecutar con: bundle exec rails runner test_cron_data.rb

puts "Creating test data for cron jobs..."

# Crear usuarios
admin = User.find_or_create_by!(email: 'admin@test.com') do |u|
  u.password = 'password123'
  u.name = 'Admin User'
  u.role = 'admin'
end

manager = User.find_or_create_by!(email: 'manager@test.com') do |u|
  u.password = 'password123'
  u.name = 'Manager User'
  u.role = 'production_manager'
end

operator = User.find_or_create_by!(email: 'operator@test.com') do |u|
  u.password = 'password123'
  u.name = 'Operator User'
  u.role = 'operator'
end

puts "✓ Users created"

# Crear orden normal con tarea vencida
normal_order = NormalOrder.create!(
  creator: manager,
  status: 'pending',
  start_date: 2.weeks.ago,
  expected_end_date: 1.week.from_now
)

OrderAssignment.create!(user: operator, production_order: normal_order)

# Crear tarea vencida
expired_task = Task.create!(
  production_order: normal_order,
  description: 'Expired Task - Should trigger notification',
  status: 'pending',
  expected_end_date: 3.days.ago
)

puts "✓ Created NormalOrder ##{normal_order.order_number} with expired task"

# Crear orden urgente con deadline próximo (1 día)
urgent_order_1 = UrgentOrder.create!(
  creator: manager,
  status: 'pending',
  start_date: Date.current,
  expected_end_date: Date.current + 1.day,
  deadline: Date.current + 1.day
)

OrderAssignment.create!(user: operator, production_order: urgent_order_1)

puts "✓ Created UrgentOrder ##{urgent_order_1.order_number} with deadline in 1 day"

# Crear orden urgente con deadline próximo (2 días)
urgent_order_2 = UrgentOrder.create!(
  creator: manager,
  status: 'pending',
  start_date: Date.current,
  expected_end_date: Date.current + 2.days,
  deadline: Date.current + 2.days
)

OrderAssignment.create!(user: admin, production_order: urgent_order_2)

puts "✓ Created UrgentOrder ##{urgent_order_2.order_number} with deadline in 2 days"

puts "\n=========================================="
puts "Test data created successfully!"
puts "=========================================="
puts "\nExpected notifications:"
puts "1. ExpiredTasksNotificationJob should notify:"
puts "   - #{manager.email} (creator)"
puts "   - #{operator.email} (assigned)"
puts "   About Task ##{expired_task.id} from Order #{normal_order.order_number}"
puts ""
puts "2. UrgentDeadlineReminderJob should notify:"
puts "   - About UrgentOrder #{urgent_order_1.order_number} (deadline: #{urgent_order_1.deadline})"
puts "   - About UrgentOrder #{urgent_order_2.order_number} (deadline: #{urgent_order_2.deadline})"
puts ""
puts "To test manually:"
puts "  bundle exec rails runner 'ExpiredTasksNotificationJob.perform_now'"
puts "  bundle exec rails runner 'UrgentDeadlineReminderJob.perform_now'"
puts "=========================================="
