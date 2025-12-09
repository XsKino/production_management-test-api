# IMPROVEMENTS.md

Registro de mejoras técnicas implementadas en el proyecto.

---

## 1. Centralizar Manejo de Errores CRUD

### Cambios

- Agregado `rescue_from ActiveRecord::RecordNotDestroyed` y `RecordNotSaved` en `Api::ErrorHandling`
- Refactorizado 3 controladores para usar métodos bang (`save!`, `update!`, `destroy!`)
- Eliminados bloques `if/else` repetitivos en 11 acciones CRUD

### Archivos modificados

- `app/controllers/concerns/api/error_handling.rb`
- `app/controllers/api/v1/production_orders_controller.rb`
- `app/controllers/api/v1/tasks_controller.rb`
- `app/controllers/api/v1/users_controller.rb`

### Impacto

- **~80 líneas de código eliminadas**
- Manejo de errores consistente en toda la API
- Tests: 269 examples, 0 failures

---

## 2. Optimizar urgent_orders_report - Single Query

### Cambios

- Modificado query para retornar última tarea pendiente completa (no solo fecha)
- Implementado usando **LATERAL JOIN** con `ANY_VALUE()` (MySQL 8.0.14+)
- Actualizada serialización para incluir objeto completo de `latest_pending_task`

### Archivos modificados

- `app/controllers/api/v1/production_orders_controller.rb`

### Detalles técnicos

- Usamos **LATERAL JOIN** para obtener la última tarea pendiente (id máximo) con todos sus campos
- `ANY_VALUE()` evita conflictos con `sql_mode=only_full_group_by`
- Dos JOINs diferentes:
  - **JOIN 1**: `LEFT JOIN tasks` - Para calcular estadísticas agregadas (counts, percentages)
  - **JOIN 2**: `LEFT JOIN LATERAL` - Para traer los 6 campos de la última tarea pendiente específica
- Query optimizado para un solo round-trip a la base de datos
- Compatible con MySQL 8.0.14+ y MySQL 9.x

### Formato de respuesta

```json
{
  ...
  "latest_pending_task": {
    "id": 123,
    "description": "Revisión de calidad",
    "expected_end_date": "2025-12-15",
    "status": "pending",
    "created_at": "2025-12-08T10:00:00.000Z",
    "updated_at": "2025-12-08T10:00:00.000Z"
  }
}
```

### Impacto

- Query más eficiente - single query, no hay problema de N+1
- Información completa de la tarea disponible en el cliente
- Tests: All passing

---

## 3. Centralizar Autorización con Callbacks y DRY

### Cambios

**Fase 1: Autorización en Callbacks (por controlador)**

- Creado método `authorize_resource` en cada controlador
- Implementado patrón de convención sobre configuración (acción → policy automática)
- Separada responsabilidad: `set_*` solo busca, `authorize_resource` solo autoriza
- Eliminadas ~15 llamadas manuales a `authorize` en 3 controladores

**Fase 2: DRY - Centralización en ApplicationController**

- Movido método `authorize_resource` desde 3 controladores a `Api::V1::ApplicationController`
- Implementado usando convención genérica: `controller_name.singularize` → variable de instancia
- Eliminados ~45 líneas adicionales de código repetitivo (3 métodos completos)
- Usado constante `POLICY_MAPPING` para excepciones en lugar de variables locales

### Archivos modificados

- `app/controllers/api/v1/application_controller.rb` (agregado método genérico)
- `app/controllers/api/v1/production_orders_controller.rb` (agregada constante POLICY_MAPPING)
- `app/controllers/api/v1/tasks_controller.rb` (usa método del padre directamente)
- `app/controllers/api/v1/users_controller.rb` (usa método del padre directamente)

### Detalles técnicos

**Antes (Fase 0 - código original con llamadas manuales):**

```ruby
# Repetido en cada acción de cada controlador
def show
  authorize @production_order  # Manual en CADA acción
  render_success(...)
end

def update
  authorize @production_order  # Manual en CADA acción
  @production_order.update!(...)
  render_success(...)
end
# ... y así en ~15 acciones más
```

**Fase 1 (Callbacks en cada controlador - todavía repetitivo):**

```ruby
# En ProductionOrdersController
before_action :authorize_resource, except: [:create]

def authorize_resource
  policy_mapping = { audit_logs: :show }
  policy_name = "#{policy_mapping[action_name.to_sym] || action_name}?"

  if @production_order
    authorize @production_order, policy_name
  else
    authorize ProductionOrder, policy_name
  end
end

# En TasksController (casi idéntico - DUPLICACIÓN)
def authorize_resource
  policy_name = "#{action_name}?"

  if @task
    authorize @task, policy_name
  else
    authorize @task || Task, policy_name
  end
end

# En UsersController (casi idéntico - DUPLICACIÓN)
def authorize_resource
  policy_name = "#{action_name}?"

  if @user
    authorize @user, policy_name
  else
    authorize User, policy_name
  end
end
```

**Fase 2 (Máximo DRY - método genérico en ApplicationController):**

```ruby
# En Api::V1::ApplicationController (UN SOLO LUGAR)
def authorize_resource
  # 1. Determine resource based on controller name
  resource = instance_variable_get("@#{controller_name.singularize}")

  # 2. Get policy mapping from child controller if defined
  policy_mapping = defined?(self.class::POLICY_MAPPING) ? self.class::POLICY_MAPPING : {}

  # 3. Determine policy rule name
  policy_action = policy_mapping[action_name.to_sym] || action_name
  policy_name = "#{policy_action}?"

  if resource
    authorize resource, policy_name
  else
    resource_class = controller_name.singularize.classify.constantize
    authorize resource_class, policy_name
  end
end

# En ProductionOrdersController (solo constante cuando hay excepciones)
POLICY_MAPPING = {
  audit_logs: :show
}.freeze

before_action :authorize_resource, except: [:create]

# En TasksController y UsersController: NADA
# Solo declaran el before_action, heredan el método del padre
before_action :authorize_resource, except: [:create]
```

### Evolución del código

| Fase      | Descripción                              | Líneas eliminadas | Ubicación de la lógica          |
| --------- | ---------------------------------------- | ----------------- | ------------------------------- |
| 0         | Llamadas manuales                        | -                 | ~15 acciones (disperso)         |
| 1         | Callbacks por controlador                | ~15               | 3 controladores (repetitivo)    |
| 2         | Método genérico en ApplicationController | ~45 adicionales   | 1 lugar (ApplicationController) |
| **Total** | **Mejora completa**                      | **~60 líneas**    | **Centralizado y DRY**          |

### Beneficios

**De la Fase 1 (Callbacks):**

- **DRY en acciones**: ~15 líneas de `authorize` eliminadas
- **Seguridad por defecto**: Nuevos endpoints fallan si no tienen policy
- **Convención sobre configuración**: `tasks_summary` automáticamente usa `tasks_summary?`
- **Single Responsibility**: `set_*` solo busca, `authorize_resource` solo autoriza
- **Flexibilidad**: `policy_mapping` maneja casos especiales

**De la Fase 2 (DRY en ApplicationController):**

- **Máximo DRY**: ~45 líneas adicionales eliminadas (3 métodos idénticos)
- **Convención genérica**: Usa `controller_name` para determinar automáticamente el recurso
- **POLICY_MAPPING como constante**: Mejor práctica vs. variable local
- **Mantenibilidad**: Un solo lugar para actualizar la lógica de autorización
- **Extensibilidad**: Nuevos controladores heredan automáticamente esta funcionalidad

### Impacto

- **~60 líneas de código eliminadas** en total
- Código más limpio, mantenible y DRY
- Menor probabilidad de olvidar autorización (agujero de seguridad)
- Lógica de autorización centralizada en un solo lugar
- Más fácil agregar nuevos controladores (heredan automáticamente)
- Tests: 269 examples, 0 failures

---

## 4. Implementar Route Constraints para Tipos de Órdenes

### Cambios

- Creados controladores separados: `NormalOrdersController` y `UrgentOrdersController`
- Eliminado uso peligroso de `constantize` sin filtrar
- Implementado whitelist para tipos de órdenes permitidos
- Removido método `set_order_type` del ProductionOrdersController
- Actualizadas rutas para usar controladores específicos

### Archivos modificados

- `app/controllers/api/v1/normal_orders_controller.rb` (nuevo)
- `app/controllers/api/v1/urgent_orders_controller.rb` (nuevo)
- `app/controllers/api/v1/production_orders_controller.rb` (refactorizado)
- `config/routes.rb` (actualizado)

### Detalles técnicos

**Antes (código inseguro con constantize):**

```ruby
# En ProductionOrdersController
before_action :set_order_type, only: [:index, :create]

def create
  order_class = @order_type&.constantize || NormalOrder  # ⚠️ Peligroso!
  @production_order = order_class.new(production_order_params)
  # ...
end

def set_order_type
  # Determina el tipo desde params sin filtrar
  @order_type = case params[:controller]
                when 'api/v1/normal_orders'
                  'NormalOrder'
                when 'api/v1/urgent_orders'
                  'UrgentOrder'
                else
                  params[:production_order]&.[](:type) || params[:type]  # ⚠️ Sin filtrar!
                end
end

# En routes.rb
resources :normal_orders, controller: :production_orders, type: 'NormalOrder'
resources :urgent_orders, controller: :production_orders, type: 'UrgentOrder'
```

**Después (código seguro con controladores separados):**

```ruby
# Controladores específicos (nuevo)
class Api::V1::NormalOrdersController < Api::V1::ProductionOrdersController
  private
  def order_class
    NormalOrder
  end
end

class Api::V1::UrgentOrdersController < Api::V1::ProductionOrdersController
  private
  def order_class
    UrgentOrder
  end
end

# En ProductionOrdersController (refactorizado)
def create
  # Determinar clase de orden de forma segura:
  # 1. Usa order_class de controlador hijo si existe
  # 2. Whitelist para params[:type] si se especifica
  # 3. Default a NormalOrder
  klass = if respond_to?(:order_class, true)
            order_class  # Seguro: definido en controlador hijo
          elsif params.dig(:production_order, :type).present?
            # Seguro: whitelist explícita
            case params.dig(:production_order, :type)
            when 'NormalOrder'
              NormalOrder
            when 'UrgentOrder'
              UrgentOrder
            else
              NormalOrder  # Fallback seguro
            end
          else
            NormalOrder  # Default
          end

  @production_order = klass.new(production_order_params)
  # ...
end

# Método set_order_type eliminado

# En routes.rb
resources :normal_orders, only: [:index, :create]
resources :urgent_orders, only: [:index, :create]
```

### Beneficios

- ** Seguridad mejorada**: Eliminado `constantize` sin filtrar que permitía inyección de clases arbitrarias
- ** Whitelist explícita**: Solo `NormalOrder` y `UrgentOrder` permitidos
- ** Controladores separados**: Mejor organización y separación de responsabilidades
- ** Compatibilidad hacia atrás**: Funciona con `params[:production_order][:type]` existente
- ** Código más simple**: ~14 líneas de código eliminadas (método `set_order_type`)
- ** Más mantenible**: Cada controlador tiene responsabilidad única y clara

### Comparación de seguridad

| Aspecto                   | Antes (constantize)                           | Después (whitelist)                     |
| ------------------------- | --------------------------------------------- | --------------------------------------- |
| **Inyección de código**   | ⚠️ Posible (puede instanciar cualquier clase) | ✅ Imposible (solo 2 clases permitidas) |
| **Validación de entrada** | ❌ No hay whitelist                           | ✅ Case statement con whitelist         |
| **Default seguro**        | ⚠️ Fallback a NormalOrder                     | ✅ Fallback explícito a NormalOrder     |
| **Trazabilidad**          | ❌ Difícil rastrear qué clase se instancia    | ✅ Claramente visible en el código      |

### Impacto

- **Seguridad significativamente mejorada**: Eliminada vulnerabilidad potencial de inyección de clases
- **~14 líneas de código eliminadas** (método `set_order_type`)
- Código más limpio y organizado con controladores específicos
- Tests: 269 examples, 0 failures

---
## 5. DRY en Serializers - Método Centralizado

### Cambios

- Creado concern `Api::SerializationHelpers` con método genérico `serialize`
- Incluido concern en `Api::V1::ApplicationController`
- Eliminados 8 métodos de serialización repetitivos:
  - `ProductionOrdersController`: `serialize_orders`, `serialize_order`, `serialize_order_with_tasks`, `serialize_task`, `format_order_data` (5 métodos)
  - `TasksController`: `serialize_task` (1 método)
  - `UsersController`: `serialize_users`, `serialize_user`, `serialize_user_detail` (3 métodos)

### Archivos modificados

- `app/controllers/concerns/api/serialization_helpers.rb` (nuevo)
- `app/controllers/api/v1/application_controller.rb` (incluido concern)
- `app/controllers/api/v1/production_orders_controller.rb` (eliminados 5 métodos)
- `app/controllers/api/v1/tasks_controller.rb` (eliminado 1 método)
- `app/controllers/api/v1/users_controller.rb` (eliminados 3 métodos)

### Detalles técnicos

**Antes (código repetitivo en cada controlador):**

```ruby
# En ProductionOrdersController (~70 líneas)
def serialize_orders(orders)
  serializer_class = orders.first&.class == UrgentOrder ? UrgentOrderSerializer : ProductionOrderSerializer
  serializer_class.new(orders, include: [:creator, :assigned_users])
                  .serializable_hash[:data]
                  .map { |o| format_order_data(o) }
end

def serialize_order(order)
  serializer_class = order.is_a?(UrgentOrder) ? UrgentOrderSerializer : ProductionOrderSerializer
  data = serializer_class.new(order, include: [:creator, :assigned_users])
                         .serializable_hash
  format_order_data(data[:data])
end

def serialize_order_with_tasks(order)
  serializer_class = order.is_a?(UrgentOrder) ? UrgentOrderSerializer : ProductionOrderSerializer
  data = serializer_class.new(order, include: [:creator, :assigned_users, :tasks])
                         .serializable_hash
  formatted = format_order_data(data[:data], data[:included])

  formatted.merge({
    tasks_summary: {
      total: order.tasks.size,
      pending: order.tasks.select(&:pending?).size,
      completed: order.tasks.select(&:completed?).size,
      completion_percentage: calculate_completion_percentage(order)
    }
  })
end

def serialize_task(task)
  TaskSerializer.new(task).serializable_hash[:data][:attributes].merge({
    is_overdue: task.expected_end_date < Date.current && task.pending?
  })
end

def format_order_data(data, included = nil)
  # ~40 líneas de lógica para extraer attributes y relationships
  # ...
end

# En TasksController (~5 líneas - DUPLICACIÓN)
def serialize_task(task)
  TaskSerializer.new(task).serializable_hash[:data][:attributes].merge({
    is_overdue: task.expected_end_date < Date.current && task.pending?
  })
end

# En UsersController (~20 líneas)
def serialize_users(users)
  UserSerializer.new(users).serializable_hash[:data].map { |u| u[:attributes] }
end

def serialize_user(user)
  UserSerializer.new(user).serializable_hash[:data][:attributes]
end

def serialize_user_detail(user)
  serialized = UserSerializer.new(user).serializable_hash[:data][:attributes]
  serialized.merge({
    statistics: {
      created_orders_count: user.created_orders.count,
      assigned_orders_count: user.assigned_orders.count,
      pending_orders_count: user.assigned_orders.where(status: :pending).count,
      completed_orders_count: user.assigned_orders.where(status: :completed).count
    }
  })
end
```

**Después (método genérico en concern - UN SOLO LUGAR):**

```ruby
# En app/controllers/concerns/api/serialization_helpers.rb
module Api
  module SerializationHelpers
    extend ActiveSupport::Concern

    # Generic method to serialize resources using Fast JSON API serializers
    def serialize(resource, options = {})
      return nil if resource.nil?

      # Determine if resource is a collection
      is_collection = resource.is_a?(ActiveRecord::Relation) || resource.is_a?(Array)

      # Determine serializer class automatically
      serializer_class = options[:serializer] || determine_serializer_class(resource, is_collection)

      # Build serializer options
      serializer_opts = {}
      serializer_opts[:include] = options[:include] if options[:include]

      # Serialize using Fast JSON API
      serialized = serializer_class.new(resource, serializer_opts).serializable_hash

      # Extract data and format (handles included relationships automatically)
      data = is_collection ?
        serialized[:data].map { |item| extract_attributes(item, serialized[:included]) } :
        extract_attributes(serialized[:data], serialized[:included])

      # Apply merge if provided
      data = is_collection ?
        data.map { |item| item.merge(options[:merge]) } :
        data.merge(options[:merge]) if options[:merge]

      data
    end

    private

    # Automatically determines serializer based on resource class (handles STI)
    def determine_serializer_class(resource, is_collection)
      # ...
    end

    # Extracts attributes and merges included relationships
    def extract_attributes(data, included = nil)
      # Automatically handles FastJsonApi format and relationships
      # ...
    end
  end
end

# Uso en controladores (mucho más simple):
# ProductionOrdersController
serialize(@orders, include: [:creator, :assigned_users])
serialize(@production_order, include: [:creator, :assigned_users, :tasks])
serialize(task, merge: { is_overdue: task.expected_end_date < Date.current && task.pending? })

# TasksController
serialize(@task, merge: { is_overdue: @task.expected_end_date < Date.current && @task.pending? })

# UsersController
serialize(@users)
serialize(@user)
serialized = serialize(@user)
serialized.merge(statistics: { ... })
```

### Características del método genérico

1. **Detección automática de serializer**: Usa convención `ModelNameSerializer` (soporta STI)
2. **Soporte para colecciones y recursos únicos**: Detecta automáticamente
3. **Include de relaciones**: Maneja relaciones has_many y belongs_to automáticamente
4. **Merge de atributos adicionales**: Permite agregar campos computed con `merge:`
5. **Extracción automática de included**: Convierte formato FastJsonApi a hash plano
6. **Manejo de tipos de FastJsonApi**: Resuelve diferencia entre tipos en relationships (`:assigned_user`) vs included (`:user`)

### Beneficios

- **~95 líneas de código eliminadas**: 8 métodos completos removidos
- **DRY máximo**: Un solo lugar para lógica de serialización
- **Más fácil de mantener**: Cambios en serialización se hacen en un solo lugar
- **Convención sobre configuración**: Determina automáticamente el serializer a usar
- **Flexible**: Soporta merge, includes, y transformaciones custom
- **Reutilizable**: Cualquier nuevo controlador puede usar el método inmediatamente
- **Type-safe**: Valida que el serializer exista y da error claro si falta

### Impacto

- **~95 líneas de código eliminadas** en total
- Código más limpio, DRY y mantenible
- Menos probabilidad de bugs por duplicación
- Más fácil agregar nuevos modelos (heredan automáticamente)
- Tests: 269 examples, 0 failures

---
## 6. Implementar Strong Params con Pundit

### Cambios

- Agregados métodos `permitted_attributes_for_create` y `permitted_attributes_for_update` en 3 policies
- Eliminados 4 métodos de strong params de controladores
- Toda la lógica de permisos ahora reside en las policies (responsabilidad única)

### Archivos modificados

- `app/policies/production_order_policy.rb` (agregados métodos permitted_attributes)
- `app/policies/task_policy.rb` (agregados métodos permitted_attributes)
- `app/policies/user_policy.rb` (agregados métodos permitted_attributes con lógica admin/non-admin)
- `app/controllers/api/v1/production_orders_controller.rb` (eliminado `production_order_params`)
- `app/controllers/api/v1/tasks_controller.rb` (eliminado `task_params`)
- `app/controllers/api/v1/users_controller.rb` (eliminados `user_params` y `user_self_update_params`)

### Detalles técnicos

**Antes (strong params en controladores):**

```ruby
# En ProductionOrdersController (~14 líneas)
def production_order_params
  permitted_params = [:start_date, :expected_end_date, :status,
                     tasks_attributes: [:id, :description, :expected_end_date, :status, :_destroy]]

  # Add deadline for urgent orders
  if respond_to?(:order_class, true) && order_class == UrgentOrder
    permitted_params << :deadline
  elsif params.dig(:production_order, :type) == 'UrgentOrder'
    permitted_params << :deadline
  end

  params.require(:production_order).permit(permitted_params)
end

# En TasksController (~3 líneas)
def task_params
  params.require(:task).permit(:description, :expected_end_date, :status)
end

# En UsersController (~8 líneas - DOS MÉTODOS)
def user_params
  params.require(:user).permit(:name, :email, :password, :password_confirmation, :role)
end

def user_self_update_params
  params.require(:user).permit(:name, :email, :password, :password_confirmation)
end

# Uso en acciones
def create
  @production_order = klass.new(production_order_params)  # Controlador decide permisos
  # ...
end

def update
  update_params = current_user.admin? ? user_params : user_self_update_params  # Lógica duplicada
  @user.update!(update_params)
end
```

**Después (permisos delegados a policies):**

```ruby
# En ProductionOrderPolicy
def permitted_attributes_for_create
  base_attrs = [:start_date, :expected_end_date, :status,
               tasks_attributes: [:id, :description, :expected_end_date, :status, :_destroy]]

  # Add deadline for UrgentOrder
  base_attrs << :deadline if record.is_a?(UrgentOrder)

  base_attrs
end

def permitted_attributes_for_update
  permitted_attributes_for_create
end

# En TaskPolicy
def permitted_attributes_for_create
  [:description, :expected_end_date, :status]
end

def permitted_attributes_for_update
  [:description, :expected_end_date, :status]
end

# En UserPolicy (con lógica de admin)
def permitted_attributes_for_create
  # Only admin can create users, so they get all fields
  [:name, :email, :password, :password_confirmation, :role]
end

def permitted_attributes_for_update
  if admin?
    # Admin can update all fields
    [:name, :email, :password, :password_confirmation, :role]
  else
    # Non-admin can only update their own profile (limited fields)
    [:name, :email, :password, :password_confirmation]
  end
end

# Uso en controladores (mucho más limpio)
def create
  temp_order = klass.new
  permitted_attrs = policy(temp_order).permitted_attributes_for_create
  @production_order = klass.new(params.require(:production_order).permit(permitted_attrs))
  # ...
end

def update
  permitted_attrs = policy(@user).permitted_attributes_for_update  # Policy decide permisos
  @user.update!(params.require(:user).permit(permitted_attrs))
end
```

### Beneficios

- **Single Responsibility**: Policies ahora manejan TODA la autorización (tanto permisos como atributos permitidos)
- **DRY**: Eliminada duplicación de lógica (ej. `user_params` vs `user_self_update_params`)
- **Consistencia**: Mismo patrón en todos los controladores
- **Seguridad mejorada**: Permisos centralizados en policies, no dispersos en controladores
- **Más mantenible**: Cambios en permisos solo requieren editar la policy
- **Lógica declarativa**: Los permisos están junto a las reglas de autorización

### Características especiales

1. **UrgentOrder detection**: Policy detecta automáticamente si `record.is_a?(UrgentOrder)` para permitir `:deadline`
2. **Admin/non-admin logic**: `UserPolicy` usa lógica condicional para permitir `:role` solo a admins
3. **Convención**: Métodos `permitted_attributes_for_create` y `permitted_attributes_for_update` siguen convención de Pundit

### Impacto

- **~25 líneas de código eliminadas** (4 métodos de strong params)
- Código más limpio y organizado
- Autorización completamente centralizada en policies
- Tests: 269 examples, 0 failures

---

## 7. Centralizar Estructura de Cache Keys en Service Object

### Cambios

- Creado `MonthlyStatisticsCacheService` para gestionar cache keys y invalidación
- Eliminados 2 métodos privados de `ProductionOrdersController`
- Centralizada lógica de cache que estaba dispersa en el controlador

### Archivos modificados

- `app/services/monthly_statistics_cache_service.rb` (nuevo)
- `app/controllers/api/v1/production_orders_controller.rb` (refactorizado)

### Detalles técnicos

**Antes (lógica dispersa en controlador):**

```ruby
# En ProductionOrdersController (~37 líneas)

# Método 1: Generar cache key (líneas 425-432)
def monthly_statistics_cache_key(user, month_start)
  key_parts = ['monthly_stats', user.role, month_start.year, month_start.month]

  # Operators only see their own orders, so include user_id in cache key
  key_parts.insert(2, user.id) if user.operator?

  key_parts.join('/')
end

# Método 2: Invalidar cache (líneas 435-461)
def invalidate_monthly_statistics_cache
  current_month_start = Date.current.beginning_of_month

  # Invalidate cache for all roles that might be affected
  # Admins and production_managers see all orders, so invalidate their cache
  %w[admin production_manager].each do |role|
    cache_key = ['monthly_stats', role, current_month_start.year, current_month_start.month].join('/')
    Rails.cache.delete(cache_key)
  end

  # For operators, invalidate cache for creator and assigned users
  if @production_order
    # Invalidate creator's cache if they're an operator
    if @production_order.creator&.operator?
      cache_key = ['monthly_stats', 'operator', @production_order.creator.id,
                   current_month_start.year, current_month_start.month].join('/')
      Rails.cache.delete(cache_key)
    end

    # Invalidate assigned operators' cache
    @production_order.assigned_users.where(role: :operator).each do |user|
      cache_key = ['monthly_stats', 'operator', user.id,
                   current_month_start.year, current_month_start.month].join('/')
      Rails.cache.delete(cache_key)
    end
  end
end

# Uso en acciones
def monthly_statistics
  cache_key = monthly_statistics_cache_key(current_user, current_month_start)
  # ...
end

def create
  # ...
  invalidate_monthly_statistics_cache
end
```

**Después (service object centralizado):**

```ruby
# En app/services/monthly_statistics_cache_service.rb
class MonthlyStatisticsCacheService
  CACHE_KEY_PREFIX = 'monthly_stats'
  GLOBAL_ROLES = %w[admin production_manager].freeze

  class << self
    # Generate cache key for monthly statistics
    def build_key(user, month_start = Date.current.beginning_of_month)
      key_parts = [CACHE_KEY_PREFIX, user.role, month_start.year, month_start.month]

      # Operators only see their own orders, so include user_id in cache key
      key_parts.insert(2, user.id) if user.operator?

      key_parts.join('/')
    end

    # Invalidate monthly statistics cache for the current month
    # Intelligently invalidates only the caches that might be affected by the order
    def invalidate(production_order = nil, month_start = Date.current.beginning_of_month)
      invalidated_keys = []

      # Invalidate cache for all roles that see all orders (admin, production_manager)
      invalidated_keys += invalidate_global_roles(month_start)

      # Invalidate cache for specific operators affected by this order
      if production_order
        invalidated_keys += invalidate_affected_operators(production_order, month_start)
      end

      invalidated_keys
    end

    private

    # Invalidate cache for roles that see all orders
    def invalidate_global_roles(month_start)
      GLOBAL_ROLES.map do |role|
        cache_key = [CACHE_KEY_PREFIX, role, month_start.year, month_start.month].join('/')
        Rails.cache.delete(cache_key)
        cache_key
      end
    end

    # Invalidate cache for operators affected by the production order
    def invalidate_affected_operators(production_order, month_start)
      invalidated_keys = []

      # Invalidate creator's cache if they're an operator
      if production_order.creator&.operator?
        cache_key = build_operator_key(production_order.creator.id, month_start)
        Rails.cache.delete(cache_key)
        invalidated_keys << cache_key
      end

      # Invalidate assigned operators' cache
      production_order.assigned_users.where(role: :operator).each do |user|
        cache_key = build_operator_key(user.id, month_start)
        Rails.cache.delete(cache_key)
        invalidated_keys << cache_key
      end

      invalidated_keys
    end

    # Build cache key for a specific operator
    def build_operator_key(operator_id, month_start)
      [CACHE_KEY_PREFIX, 'operator', operator_id, month_start.year, month_start.month].join('/')
    end
  end
end

# Uso en ProductionOrdersController (mucho más simple)
def monthly_statistics
  cache_key = MonthlyStatisticsCacheService.build_key(current_user, current_month_start)
  # ...
end

def create
  # ...
  MonthlyStatisticsCacheService.invalidate(@production_order)
end

def update
  # ...
  MonthlyStatisticsCacheService.invalidate(@production_order)
end

def destroy
  # ...
  MonthlyStatisticsCacheService.invalidate(@production_order)
end
```

### Beneficios

- **Service Object Pattern**: Lógica de cache encapsulada en objeto con responsabilidad única
- **Mejor organización**: Cache logic separada de la lógica del controlador
- **Más testeable**: Service object puede ser testeado independientemente
- **Documentación mejorada**: Métodos bien documentados con ejemplos
- **Inteligente**: Retorna array de cache keys invalidados (útil para debugging/logging)
- **Constantes**: `CACHE_KEY_PREFIX` y `GLOBAL_ROLES` como constantes explícitas
- **Métodos privados**: Lógica de invalidación separada en métodos privados claros

### Características del service object

1. **build_key**: Genera cache key basado en rol y mes (incluye user_id para operators)
2. **invalidate**: Invalida cache inteligentemente solo para usuarios afectados
3. **invalidate_global_roles**: Invalida cache para admins y production_managers (ven todas las órdenes)
4. **invalidate_affected_operators**: Invalida cache solo para operators que crearon o están asignados a la orden
5. **build_operator_key**: Helper para construir cache key de operador específico

### Formato de cache key

```
monthly_stats/{role}/{user_id_if_operator}/{year}/{month}

Ejemplos:
- monthly_stats/admin/2025/12
- monthly_stats/production_manager/2025/12
- monthly_stats/operator/123/2025/12  (incluye user_id)
```

### Impacto

- **~37 líneas de código eliminadas** (2 métodos privados del controlador)
- Código más limpio y organizado
- Lógica de cache centralizada en un solo lugar
- Más fácil de mantener y extender
- Tests: 269 examples, 0 failures

---
