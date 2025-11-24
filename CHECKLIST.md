# Checklist de Implementación - Sistema de Órdenes de Producción

Basado en requirements.pdf y análisis del código actual.

## ✅ Completado

### Modelos y Base de Datos
- [x] Modelo User con roles (operator, production_manager, admin)
- [x] Autenticación con bcrypt (has_secure_password)
- [x] Validación de email único
- [x] Modelo ProductionOrder con STI (Single Table Inheritance)
- [x] Submodelos NormalOrder y UrgentOrder
- [x] Campo deadline exclusivo para UrgentOrder
- [x] Auto-incremento de order_number por tipo de orden
- [x] Modelo Task con relación a ProductionOrder
- [x] Estados de órdenes (pending, completed, cancelled)
- [x] Estados de tareas (pending, completed)
- [x] Modelo OrderAssignment para asignación de usuarios a órdenes
- [x] Índices únicos para (type, order_number) y (user_id, production_order_id)

### API Endpoints - Production Orders
- [x] GET /api/v1/production_orders - Listar órdenes con paginación
- [x] GET /api/v1/production_orders/:id - Ver detalle de orden con tareas
- [x] POST /api/v1/production_orders - Crear orden con tareas anidadas
- [x] PATCH /api/v1/production_orders/:id - Actualizar orden
- [x] DELETE /api/v1/production_orders/:id - Eliminar orden
- [x] GET /api/v1/production_orders/:id/tasks_summary - Resumen de tareas
- [x] GET /api/v1/production_orders/monthly_statistics - Estadísticas mensuales
- [x] GET /api/v1/production_orders/urgent_orders_report - Reporte de órdenes urgentes
- [x] GET /api/v1/production_orders/urgent_with_expired_tasks - Órdenes urgentes con tareas vencidas

### API Endpoints - Tasks
- [x] POST /api/v1/production_orders/:production_order_id/tasks - Crear tarea
- [x] PATCH /api/v1/production_orders/:production_order_id/tasks/:id - Actualizar tarea
- [x] DELETE /api/v1/production_orders/:production_order_id/tasks/:id - Eliminar tarea
- [x] PATCH /api/v1/production_orders/:production_order_id/tasks/:id/complete - Marcar completada
- [x] PATCH /api/v1/production_orders/:production_order_id/tasks/:id/reopen - Reabrir tarea

### Funcionalidades de Búsqueda y Filtrado
- [x] Integración de Ransack para búsquedas avanzadas
- [x] Configuración ransackable_attributes en todos los modelos
- [x] Configuración ransackable_associations en todos los modelos
- [x] Filtrado por tipo de orden (NormalOrder/UrgentOrder)
- [x] Filtrado por estado
- [x] Filtrado por rangos de fecha
- [x] Paginación con Kaminari (20 items por defecto, máximo 100)

### Testing
- [x] Model specs para User
- [x] Model specs para ProductionOrder, NormalOrder, UrgentOrder
- [x] Model specs para Task
- [x] Model specs para OrderAssignment
- [x] Controller specs para ProductionOrdersController
- [x] Integration specs para API endpoints
- [x] Integration specs para autenticación JWT
- [x] Factories con FactoryBot
- [x] 113 tests pasando exitosamente

### Infraestructura
- [x] Concerns para manejo de errores (Api::ErrorHandling)
- [x] Concerns para respuestas estandarizadas (Api::ResponseHelpers)
- [x] Serialización manual de respuestas JSON
- [x] Configuración de CORS
- [x] Health check endpoint

### Autenticación JWT
- [x] Implementación de JWT (JsonWebToken service)
- [x] POST /api/v1/auth/login - Login con JWT
- [x] POST /api/v1/auth/logout - Logout
- [x] POST /api/v1/auth/refresh - Refresh token
- [x] Authentication middleware con JWT en ApplicationController
- [x] Tests de integración para autenticación (113 tests pasando)
- [x] Autoload de app/services configurado

### API Endpoints - Users
- [x] GET /api/v1/users - Listar usuarios con paginación
- [x] GET /api/v1/users/:id - Ver detalle de usuario con estadísticas
- [x] POST /api/v1/users - Crear usuario (solo admin)
- [x] PATCH /api/v1/users/:id - Actualizar usuario
- [x] DELETE /api/v1/users/:id - Eliminar usuario (solo admin)
- [x] Autorización básica por roles

### API Endpoints - Order Assignments
- [x] POST /api/v1/order_assignments - Asignar usuario a orden
- [x] DELETE /api/v1/order_assignments/:id - Quitar asignación
- [x] Asignación de usuarios durante creación de orden (user_ids parameter)
- [x] Actualización de asignaciones durante update de orden

### Documentación
- [x] API.md completo con todos los endpoints
- [x] Ejemplos de requests/responses
- [x] Documentación de autenticación JWT
- [x] Códigos de error documentados
- [x] Filtros Ransack documentados

## ❌ Pendiente

### Autenticación y Autorización
- [ ] **IMPORTANTE**: Implementar Pundit para autorización granular
  - `app/controllers/api/v1/production_orders_controller.rb:10,226`
  - `app/controllers/api/v1/tasks_controller.rb:84,93`
  - `app/controllers/api/v1/order_assignments_controller.rb:50`
  - Actualmente usa lógica básica de roles en authorized_orders

### API Endpoints Faltantes
- [ ] GET /api/v1/production_orders/:production_order_id/tasks - Listar todas las tasks de una orden
  - Actualmente se obtienen tasks via GET /production_orders/:id (incluye tasks en response)
  - Considerado: ¿es necesario un endpoint dedicado solo para listar tasks?

### Funcionalidades de Negocio
- [ ] Validación de que deadline de UrgentOrder no puede ser anterior a start_date
- [ ] Validación de que expected_end_date no puede ser anterior a start_date
- [ ] Cálculo automático de order_number al cambiar tipo de orden
- [ ] Notificaciones para tareas vencidas (requiere Sidekiq)
- [ ] Notificaciones para órdenes urgentes próximas a deadline
- [ ] Logs de auditoría para cambios en órdenes

### Background Jobs (Sidekiq)
- [ ] Configurar Sidekiq y Redis
- [ ] Job para envío de notificaciones de tareas vencidas
- [ ] Job para envío de recordatorios de deadlines
- [ ] Job para generación de reportes periódicos

### Optimizaciones
- [ ] Implementar fast_jsonapi para serialización (gem ya instalada, serialización manual actual funciona)
- [ ] Agregar índices adicionales para queries comunes
- [ ] Implementar caché para estadísticas mensuales
- [ ] N+1 query prevention con bullet gem
- [x] Includes optimizados en queries principales (.includes(:creator, :assigned_users, :tasks))

### Testing Adicional
- [ ] Tests de autorización con Pundit
- [ ] Tests de performance para queries complejas
- [ ] Tests de integración para background jobs
- [ ] Tests de validaciones de fechas

### DevOps y Deployment
- [ ] Configuración de ambientes (staging, production)
- [ ] Variables de ambiente documentadas (.env.example)
- [ ] Docker setup
- [ ] CI/CD pipeline
- [ ] Monitoring y logging

## 📊 Resumen

**Completado**: ~85%
- ✅ Modelos y relaciones: 100%
- ✅ API CRUD completo: 100%
- ✅ Tests: 100% (113 tests passing)
- ✅ Autenticación JWT: 100%
- ✅ Autorización básica por roles: 100%
- ✅ Documentación API (API.md): 100%
- ❌ Autorización granular (Pundit): 0%
- ❌ Background Jobs: 0%
- ❌ DevOps/Docker: 0%

## 🎯 Prioridades Sugeridas

1. **Alta Prioridad** (Mejoras de seguridad):
   - Implementar Pundit para autorización granular por recursos
   - Validaciones de fechas (expected_end_date >= start_date, deadline >= start_date)

2. **Media Prioridad** (Funcionalidad adicional):
   - Background jobs para notificaciones (Sidekiq)
   - Endpoint GET /tasks para listar tasks de una orden (si se considera necesario)

3. **Baja Prioridad** (Nice to have):
   - Swagger/OpenAPI documentation
   - Optimizaciones de performance (caching, fast_jsonapi)
   - Setup de Docker y CI/CD
