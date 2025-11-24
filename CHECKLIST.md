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

### Autenticación JWT

- [x] Implementación de JWT (JsonWebToken service)
- [x] POST /api/v1/auth/login - Login con JWT
- [x] POST /api/v1/auth/logout - Logout
- [x] POST /api/v1/auth/refresh - Refresh token
- [x] Authentication middleware con JWT en ApplicationController
- [x] Autoload de app/services configurado

### Autorización con Pundit

- [x] **Implementación completa de Pundit**
- [x] ProductionOrderPolicy con permisos granulares por rol
- [x] TaskPolicy con permisos granulares por rol
- [x] UserPolicy con permisos granulares por rol
- [x] NormalOrderPolicy (hereda de ProductionOrderPolicy)
- [x] UrgentOrderPolicy (hereda de ProductionOrderPolicy)
- [x] Scopes para filtrado automático según rol y asignaciones
- [x] Integración en todos los controllers (Users, ProductionOrders, Tasks)
- [x] Manejo de errores de autorización (403 Forbidden)

### API Endpoints - Users

- [x] GET /api/v1/users - Listar usuarios con paginación
- [x] GET /api/v1/users/:id - Ver detalle de usuario con estadísticas
- [x] POST /api/v1/users - Crear usuario (solo admin)
- [x] PATCH /api/v1/users/:id - Actualizar usuario
- [x] DELETE /api/v1/users/:id - Eliminar usuario (solo admin)
- [x] Autorización con Pundit integrada

### API Endpoints - Order Assignments

- [x] POST /api/v1/order_assignments - Asignar usuario a orden
- [x] DELETE /api/v1/order_assignments/:id - Quitar asignación
- [x] Asignación de usuarios durante creación de orden (user_ids parameter)
- [x] Actualización de asignaciones durante update de orden

### Testing

- [x] Model specs para User
- [x] Model specs para ProductionOrder, NormalOrder, UrgentOrder
- [x] Model specs para Task
- [x] Model specs para OrderAssignment
- [x] Controller specs para ProductionOrdersController
- [x] Integration specs para API endpoints
- [x] Integration specs para autenticación JWT
- [x] **Policy specs para UserPolicy (14 tests)**
- [x] **Policy specs para ProductionOrderPolicy (36 tests)**
- [x] **Policy specs para TaskPolicy (37 tests)**
- [x] Factories con FactoryBot
- [x] **229 tests pasando exitosamente (includes model, controller, integration, policy, job, and mailer specs)**

### Infraestructura

- [x] Concerns para manejo de errores (Api::ErrorHandling)
- [x] Concerns para respuestas estandarizadas (Api::ResponseHelpers)
- [x] Serialización manual de respuestas JSON
- [x] Configuración de CORS
- [x] Health check endpoint

### Documentación

- [x] API.md completo con todos los endpoints
- [x] Ejemplos de requests/responses
- [x] Documentación de autenticación JWT
- [x] Documentación de autorización y roles con Pundit
- [x] Códigos de error documentados
- [x] Filtros Ransack documentados

### Background Jobs (Sidekiq)

- [x] **Configurar Sidekiq y Redis**
- [x] **Job para envío de notificaciones de tareas vencidas (ExpiredTasksNotificationJob)**
- [x] **Job para envío de recordatorios de deadlines (UrgentDeadlineReminderJob)**
- [x] **Scheduling automático con Whenever (cron jobs)**
- [x] **Documentación de scheduling (SCHEDULING.md)**
- [x] **Tests de jobs (12 tests)**

## ❌ Pendiente

### Funcionalidades de Negocio

- [x] **Validación de que deadline de UrgentOrder no puede ser anterior a start_date**
- [x] **Validación de que expected_end_date no puede ser anterior a start_date**
- [x] **Cálculo automático de order_number al cambiar tipo de orden**
- [x] **Notificaciones para tareas vencidas (implementado con Sidekiq)**
- [x] **Notificaciones para órdenes urgentes próximas a deadline (implementado con Sidekiq)**
- [x] **Logs de auditoría para cambios en órdenes**
  - Modelo OrderAuditLog con tracking completo
  - Concern Auditable para logging automático (create, update, delete)
  - Detección de cambios específicos (status_changed, type_changed)
  - Endpoint GET /api/v1/production_orders/:id/audit_logs
  - Contexto de auditoría (Current.user, IP, User Agent)
  - 24 tests para auditoría

### Optimizaciones

- [x] **Implementar fast_jsonapi para serialización**
  - UserSerializer
  - ProductionOrderSerializer (base para STI)
  - NormalOrderSerializer
  - UrgentOrderSerializer
  - TaskSerializer
  - Todos los controladores actualizados
- [ ] Agregar índices adicionales para queries comunes
- [ ] Implementar caché para estadísticas mensuales
- [ ] N+1 query prevention con bullet gem
- [x] Includes optimizados en queries principales (.includes(:creator, :assigned_users, :tasks))

### Testing Adicional

- [ ] Tests de performance para queries complejas
- [x] **Tests de background jobs (12 tests)**
- [x] **Tests de validaciones de fechas (6 tests agregados)**

### Seeds

- [ ] Crear seeds para generar datos de prueba a penas se inicialice la base de datos

### DevOps y Deployment

- [ ] Configuración de ambientes (staging, production)
- [ ] Variables de ambiente documentadas (.env.example)
- [ ] Docker setup
- [ ] CI/CD pipeline
- [ ] Monitoring y logging

## 📊 Resumen

**Completado**: ~95%

- ✅ Modelos y relaciones: 100%
- ✅ API CRUD completo: 100%
- ✅ Tests: 100% (253 tests passing)
- ✅ Autenticación JWT: 100%
- ✅ **Autorización granular con Pundit: 100%**
- ✅ **Validaciones de fechas: 100%**
- ✅ **Background Jobs con Sidekiq: 100%** (2 jobs implementados y testeados)
- ✅ Documentación API (API.md): 100%
- ❌ DevOps/Docker: 0%

## 🎯 Prioridades Sugeridas

1. **Alta Prioridad** (Completadas):

   - ✅ Background jobs para notificaciones (Sidekiq)
   - ✅ Validaciones de fechas

2. **Media Prioridad** (Funcionalidad adicional):

   - Endpoint GET /tasks para listar tasks de una orden (si se considera necesario)
   - Logs de auditoría para cambios en órdenes

3. **Baja Prioridad** (Nice to have):
   - Swagger/OpenAPI documentation
   - Optimizaciones de performance (caching, fast_jsonapi)
   - Setup de Docker y CI/CD
