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

## 3. Centralizar Autorización en Callbacks

### Cambios

- Creado método `authorize_resource` que centraliza toda la lógica de autorización
- Implementado patrón de convención sobre configuración (acción → policy automática)
- Separada responsabilidad: `set_*` solo busca, `authorize_resource` solo autoriza
- Eliminadas ~15 llamadas manuales a `authorize` en 3 controladores

### Archivos modificados

- `app/controllers/api/v1/production_orders_controller.rb`
- `app/controllers/api/v1/tasks_controller.rb`
- `app/controllers/api/v1/users_controller.rb`

### Detalles técnicos

**Antes (código repetitivo):**
```ruby
def show
  authorize @production_order  # Repetido en cada acción
  render_success(...)
end
```

**Después (DRY con callback):**
```ruby
before_action :authorize_resource, except: [:create]

def authorize_resource
  policy_mapping = { audit_logs: :show }  # Excepciones
  policy_name = "#{policy_mapping[action_name.to_sym] || action_name}?"

  if @production_order
    authorize @production_order, policy_name
  else
    authorize ProductionOrder, policy_name
  end
end

def show
  # Authorize implicito via callback
  render_success(...)
end
```

### Beneficios

- **DRY**: ~15 líneas de `authorize` eliminadas
- **Seguridad por defecto**: Nuevos endpoints fallan si no tienen policy definida
- **Convención sobre configuración**: `tasks_summary` automáticamente usa `tasks_summary?`
- **Single Responsibility**: `set_*` solo busca, `authorize_resource` solo autoriza
- **Flexibilidad**: `policy_mapping` maneja casos especiales limpiamente

### Impacto

- Código más limpio y mantenible
- Menor probabilidad de olvidar autorización (agujero de seguridad)
- Tests: 269 examples, 0 failures

---
