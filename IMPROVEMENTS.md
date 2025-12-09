# IMPROVEMENTS.md

Registro de mejoras técnicas implementadas en el proyecto.

---

## 1. Centralizar Manejo de Errores CRUD

**Qué se hizo:**

- Agregado `rescue_from` para manejar excepciones automáticamente
- Cambiado a métodos bang (`save!`, `update!`, `destroy!`) en 3 controladores
- Eliminados bloques `if/else` repetitivos

**Resultado:**

- **~80 líneas eliminadas**
- Manejo de errores consistente
- Tests: ✅ 269 passing

---

## 2. Optimizar urgent_orders_report - Single Query

**Qué se hizo:**

- Implementado **LATERAL JOIN** para obtener última tarea pendiente en una sola query
- Retorna objeto completo de `latest_pending_task` (antes solo fecha)

**Resultado:**

- Sin problema N+1
- Single query optimizado
- Tests: ✅ All passing

---

## 3. Centralizar Autorización con Callbacks y DRY

**Qué se hizo:**

**Fase 1:** Creado callback `authorize_resource` en cada controlador
**Fase 2:** Movido método a `ApplicationController` (DRY máximo)

**Antes:**

```ruby
def show
  authorize @production_order  # Repetido en CADA acción
  render_success(...)
end
```

**Después:**

```ruby
before_action :authorize_resource, except: [:create]
# Método heredado de ApplicationController - 1 solo lugar
```

**Resultado:**

- **~60 líneas eliminadas**
- Seguridad por defecto
- Lógica centralizada
- Tests: ✅ 269 passing

---

## 4. Separación de lógica para Tipos de Órdenes

**Qué se hizo:**

- Creados controladores `NormalOrdersController` y `UrgentOrdersController`
- Eliminado `constantize` peligroso (vulnerabilidad de inyección de clases)
- Implementada whitelist explícita

**Antes (inseguro):**

```ruby
order_class = @order_type&.constantize || NormalOrder  # Cualquier clase!
```

**Después (seguro):**

```ruby
case params.dig(:production_order, :type)
when 'NormalOrder'
  NormalOrder
when 'UrgentOrder'
  UrgentOrder
else
  NormalOrder  # Fallback seguro
end
```

**Resultado:**

- **~14 líneas eliminadas**
- Vulnerabilidad de seguridad eliminada
- Tests: ✅ 269 passing

---

## 5. DRY en Serializers - Método Centralizado

**Qué se hizo:**

- Creado concern `Api::SerializationHelpers` con método genérico `serialize`
- Eliminados 8 métodos repetitivos de serialización

**Antes:**

```ruby
# 8 métodos diferentes dispersos en 3 controladores (~95 líneas)
def serialize_orders(orders)
  # ...lógica compleja...
end

def serialize_order(order)
  # ...lógica similar...
end
# ... 6 métodos más
```

**Después:**

```ruby
# 1 método genérico en concern
serialize(@orders, include: [:creator, :assigned_users])
serialize(@task, merge: { is_overdue: ... })
```

**Características:**

- Detección automática de serializer (soporta STI)
- Maneja colecciones y recursos únicos
- Include de relaciones automático

**Resultado:**

- **~95 líneas eliminadas**
- Tests: ✅ 269 passing

---

## 6. Implementar Strong Params con Pundit

**Qué se hizo:**

- Agregados métodos `permitted_attributes_for_create/update` en 3 policies
- Eliminados 4 métodos de strong params de controladores

**Antes:**

```ruby
# En controladores (~25 líneas)
def production_order_params
  permitted_params = [...]
  permitted_params << :deadline if urgente?
  params.require(:production_order).permit(permitted_params)
end

def user_params; end
def user_self_update_params; end  # Lógica duplicada
```

**Después:**

```ruby
# En policies (responsabilidad única)
def permitted_attributes_for_update
  if admin?
    [:name, :email, :password, :password_confirmation, :role]
  else
    [:name, :email, :password, :password_confirmation]
  end
end

# En controlador
permitted_attrs = policy(@user).permitted_attributes_for_update
```

**Resultado:**

- **~25 líneas eliminadas**
- Autorización completamente centralizada en policies
- Tests: ✅ 269 passing

---

## 7. Centralizar Estructura de Cache Keys en Service Object

**Qué se hizo:**

- Creado `MonthlyStatisticsCacheService` para gestionar cache
- Eliminados 2 métodos privados de `ProductionOrdersController`

**Antes:**

```ruby
# En controlador (~37 líneas)
def monthly_statistics_cache_key(user, month_start)
  # ...lógica...
end

def invalidate_monthly_statistics_cache
  # ...lógica compleja de invalidación...
end
```

**Después:**

```ruby
# Service object
MonthlyStatisticsCacheService.build_key(current_user, month_start)
MonthlyStatisticsCacheService.invalidate(@production_order)
```

**Características del service:**

- `build_key`: Genera cache key por rol (`monthly_stats/admin/2025/12`)
- `invalidate`: Invalida inteligentemente solo caches afectados
- Retorna array de keys invalidados (debugging)

**Resultado:**

- **~37 líneas eliminadas**
- Service Object Pattern
- Lógica de cache centralizada
- Tests: ✅ 269 passing

---

## 8. Aplicar principio "Fat Models, Skinny Controllers"

**Qué se hizo:**

- Creado `tasks_summary` en ProductionOrder (retorna hash con estadísticas)
- Creado `assign_users!` y `update_assignments!` en ProductionOrder
- Movido `calculate_completion_percentage` como método privado del modelo
- Creado `order_statistics` en User (retorna hash con counts)
- Eliminados 3 bloques duplicados de tasks_summary del controlador
- Eliminados 3 métodos privados de ProductionOrdersController
- Eliminado hash manual de estadísticas en UsersController

**Resultado:**

- **~28 líneas eliminadas** (23 en ProductionOrders + 5 en Users)
- Lógica de negocio centralizada en modelos
- Queries más eficientes (4 queries → 1 en User)
- Código reutilizable en toda la app
- Tests: ✅ 269 passing

---

## 9. Refactorizar Controllers - Mover Queries SQL a Modelos

**Qué se hizo:**

- Movidas consultas SQL complejas de controllers a modelos
- Creados 3 métodos de clase en `ProductionOrder`
- Creado scope de búsqueda en `User`
- Optimizadas queries para usar asociaciones precargadas cuando están disponibles

**ProductionOrder - Nuevos métodos:**

1. `self.monthly_statistics_for(base_scope, month_start, month_end)`
   - Estadísticas mensuales (antes 20 líneas en controller)
2. `self.urgent_orders_with_report(base_scope)`
   - Query complejo con LATERAL JOIN (MySQL)
   - Obtiene última tarea pendiente + estadísticas agregadas
   - Antes: 105 líneas en controller
3. `self.urgent_with_expired_tasks(base_scope)`

   - Órdenes urgentes con tareas vencidas
   - Antes: 12 líneas en controller

4. Mejorado `tasks_summary` (optimización inteligente)
   - Usa `.loaded?` para evitar queries extras
   - Si tasks están precargados: usa memoria
   - Si no: usa database queries

**User - Nuevos métodos:**

1. `scope :search_by_name_or_email`
   - Búsqueda ILIKE reutilizable
2. Mejorado `order_statistics`
   - Antes: 4 queries separadas
   - Después: 2 queries (1 + 1 agregada con GROUP BY)

**Resultado:**

- **ProductionOrdersController:** 380 → ~280 líneas (26% reducción)
- **UsersController:** Simplificado index action
- Queries complejas en modelos (reutilizables)
- Performance mantenida (tests de performance pasan)
- Tests: ✅ 269 passing

---

## Resumen Total

| Mejora                     | Líneas Eliminadas | Beneficio Principal     |
| -------------------------- | ----------------- | ----------------------- |
| 1. Error Handling          | ~80               | Consistencia            |
| 2. LATERAL JOIN            | -                 | Performance             |
| 3. Authorization Callbacks | ~60               | Seguridad + DRY         |
| 4. Controllers Separados   | ~14               | Seguridad               |
| 5. Serializers DRY         | ~95               | DRY                     |
| 6. Strong Params Pundit    | ~25               | Centralización          |
| 7. Cache Service           | ~37               | Service Object          |
| 8. Fat Models              | ~28               | Lógica en modelos       |
| 9. SQL Queries a Modelos   | ~100              | Reusabilidad + DRY      |
| **TOTAL**                  | **~439 líneas**   | Código más limpio y DRY |

**Tests:** ✅ 269 examples, 0 failures
