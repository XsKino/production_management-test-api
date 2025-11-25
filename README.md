# Production Orders Management System API

Sistema de gestión de órdenes de producción con autenticación JWT, autorización por roles (Pundit), background jobs (Sidekiq), y optimizaciones de performance.

## Tabla de Contenidos

- [Demo en Vivo](#-demo-en-vivo)
- [Características Principales](#-características-principales)
- [Stack Tecnológico](#-stack-tecnológico)
- [Opciones de Ejecución](#-opciones-de-ejecución)
  - [Opción 1: Usar API Remota](#opción-1-usar-api-remota-railway)
  - [Opción 2: Ejecutar con Docker](#opción-2-ejecutar-con-docker-recomendado)
  - [Opción 3: Ejecutar Localmente](#opción-3-ejecutar-localmente)
- [Datos de Prueba](#-datos-de-prueba)
- [Tests](#-tests)
- [Documentación API](#-documentación-api)
- [Características Técnicas](#-características-técnicas-destacadas)

---

## Demo en Vivo

**API Base URL**: https://kiuey-test-api.up.railway.app/api/v1
**API Documentation (Swagger)**: https://kiuey-test-api.up.railway.app/api-docs

La API está desplegada en Railway y puede probarse directamente usando los links de arriba.

### Quick Test

```bash
# Health check
curl https://kiuey-test-api.up.railway.app/up

# Login test
curl -X POST https://kiuey-test-api.up.railway.app/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"admin@empresa.com","password":"password123"}'
```

---

## Características Principales

- **Autenticación JWT** con refresh tokens
- **Autorización granular** con Pundit (3 roles: admin, production_manager, operator)
- **Background Jobs** con Sidekiq para notificaciones
- **Cache Redis** para optimización de queries
- **API RESTful** con paginación, filtrado y búsqueda avanzada (Ransack)
- **Audit Trail** completo de todas las acciones
- **STI (Single Table Inheritance)** para tipos de órdenes (Normal/Urgent)
- **Docker** configuración completa con docker-compose
- **269 tests** con RSpec (100% cobertura de features críticas)
- **OpenAPI/Swagger** documentación interactiva

---

## Stack Tecnológico

- **Ruby** 3.3.6
- **Rails** 8.1.1 (API mode)
- **MySQL** 8.0
- **Redis** para cache y Sidekiq
- **Sidekiq** para background jobs
- **Pundit** para autorización
- **JWT** para autenticación
- **Ransack** para búsqueda avanzada
- **Kaminari** para paginación
- **RSpec** para testing
- **Bullet** para N+1 query detection
- **Docker** & **Docker Compose**

---

## Maneras de ejecutar el proyecto

### Opción 1: Usar API Remota (Railway)

**La forma más rápida de probar el proyecto sin instalar nada.**

La API ya está desplegada y funcionando con datos de prueba completos:

- **API Base**: `https://kiuey-test-api.up.railway.app/api/v1`
- **Swagger API Docs**: `https://kiuey-test-api.up.railway.app/api-docs`
- **Health Check**: `https://kiuey-test-api.up.railway.app/up`

**Usuarios disponibles:**

- Admin: `admin@empresa.com` / `password123`
- Manager: `manager@empresa.com` / `password123`
- Operator: `operator@empresa.com` / `password123`

**Configuración en el frontend:**

```javascript
const API_URL = "https://kiuey-test-api.up.railway.app/api/v1"

// Ejemplo de login
const login = async (email, password) => {
  const response = await fetch(`${API_URL}/auth/login`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ email, password }),
  })
  return await response.json()
}
```

---

### Opción 2: Ejecutar con Docker (Recomendado)

**La forma más rápida de ejecutar el proyecto localmente.**

#### Prerequisitos

- **Docker**: 20.x o superior
- **Docker Compose**: 2.x o superior

#### Instalación Rápida

```bash
# 1. Clonar el repositorio
git clone https://github.com/XsKino/production_management-test-api.git
cd production_management-test-api

# 2. Iniciar todos los servicios (MySQL, Redis, Rails, Sidekiq)
docker-compose up -d

# 3. Esperar a que los servicios estén listos (~30 segundos)
docker-compose logs -f web

# Cuando veas "Listening on http://0.0.0.0:3000", la API está lista
```

**API disponible en**: `http://localhost:3001`

#### Cargar Datos de Prueba

```bash
# Ejecutar seeds para crear usuarios, órdenes y tareas
docker-compose exec web bundle exec rails db:seed
```

```bash
# Si se desea testear con una database vacía hay que ignorar el comando de arriba,
# en cuyo caso, habrá que crear un usuario con rol :admin desde rails console
# Para poder hacer login con ese usuario y crear más usuarios con otros roles
# Además de gestionar el resto de recursos de la API
docker-compose exec web bundle exec rails console
>>> User.create!({name: "Admin", email: "admin@empresa.com", password: :admin})
```

Esto creará:

- 15 usuarios (2 admins, 5 managers, 8 operadores)
- ~79 órdenes de producción
- ~356 tareas
- 58 tareas expiradas para testing
- ~918 audit logs

#### Comandos Útiles

```bash
# Ver logs en tiempo real
docker-compose logs -f

# Ver logs solo de Rails
docker-compose logs -f web

# Ver logs solo de Sidekiq
docker-compose logs -f sidekiq

# Reiniciar servicios
docker-compose restart

# Detener todos los servicios
docker-compose down

# Detener y eliminar volúmenes (reset completo)
docker-compose down -v

# Ejecutar comandos dentro del container
docker-compose exec web rails console
docker-compose exec web rails db:migrate
docker-compose exec web bundle exec rspec

# Ver estado de servicios
docker-compose ps

# Reconstruir imágenes (si cambias Gemfile o archivos del proyecto)
docker-compose build
docker-compose up -d
```

#### Verificar Instalación

```bash
# Health check
curl http://localhost:3001/up

# Login test
curl -X POST http://localhost:3001/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"admin@empresa.com","password":"password123"}'

# API Documentation (Swagger UI)
open http://localhost:3001/api-docs/index.html
```

#### Servicios Incluidos

| Servicio | Puerto Local → Container | Descripción             |
| -------- | ------------------------ | ----------------------- |
| web      | 3001 → 3000              | Rails API Server        |
| db       | 3307 → 3306              | MySQL 8.0               |
| redis    | 6379 → 6379              | Redis (cache + Sidekiq) |
| sidekiq  | -                        | Background Jobs Worker  |

#### Arquitectura Docker

```
┌─────────────────────────────────────────────────┐
│            docker-compose.yml                   │
├─────────────────────────────────────────────────┤
│                                                 │
│  ┌─────────────┐  ┌──────────┐  ┌───────────┐  │
│  │    web      │  │ sidekiq  │  │   redis   │  │
│  │  (Rails)    │  │ (Jobs)   │  │           │  │
│  │ 3001→3000   │  │          │  │ 6379→6379 │  │
│  └──────┬──────┘  └────┬─────┘  └─────┬─────┘  │
│         │              │              │        │
│         └──────────────┴──────────────┘        │
│                        │                       │
│                 ┌──────┴──────┐               │
│                 │     db      │               │
│                 │  (MySQL)    │               │
│                 │ 3307→3306   │               │
│                 └─────────────┘               │
│                                                │
└─────────────────────────────────────────────────┘

Puertos mapeados para evitar conflictos con servicios locales:
- MySQL: 3307 (local) → 3306 (container)
- Rails: 3001 (local) → 3000 (container)
- Redis: 6379 (local) → 6379 (container)
```

---

### Opción 3: Ejecutar Localmente

#### Prerequisitos

- **Ruby**: 3.3.6
- **Rails**: 8.1.1
- **MySQL**: 8.x o superior
- **Redis**: 6.x o superior

#### Instalación Paso a Paso

**1. Clonar el repositorio**

```bash
git clone https://github.com/XsKino/production_management-test-api.git
cd production_management-test-api
```

**2. Instalar dependencias**

```bash
bundle install
```

**3. Configurar variables de ambiente**

```bash
cp .env.example .env
```

Editar `.env` con tus credenciales locales:

```bash
# Mínimo requerido para ejecutar localmente
DATABASE_URL=mysql2://root:tu_password@localhost/kiuey_test_api_production
REDIS_URL=redis://localhost:6379/1
JWT_SECRET_KEY=$(rails secret)
FORCE_SSL=false
ALLOWED_ORIGINS=*
```

**4. Configurar base de datos**

```bash
# Crear base de datos
RAILS_ENV=production rails db:create

# Ejecutar migraciones
RAILS_ENV=production rails db:migrate

# Cargar datos de prueba (opcional pero recomendado)
RAILS_ENV=production rails db:seed
```

**5. Iniciar servicios**

Necesitas 3 terminales:

```bash
# Terminal 1: Redis
redis-server

# Terminal 2: Sidekiq (background jobs)
bundle exec sidekiq

# Terminal 3: Rails Server
RAILS_ENV=production rails s
```

**API disponible en**: `http://localhost:3000`

#### Verificar Instalación

```bash
# Health check
curl http://localhost:3000/up

# Login test
curl -X POST http://localhost:3000/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"admin@empresa.com","password":"password123"}'
```

---

## 🧪 Datos de Prueba

El sistema incluye seeds con datos realistas distribuidos en 4 semanas.

### Usuarios de Prueba

#### Admin

```
Email: admin@empresa.com
Password: password123
```

```
Email: maria.gonzalez@empresa.com
Password: password123
```

#### Production Manager

```
Email: manager@empresa.com
Password: password123
```

```
Email: ana.martinez@empresa.com
Password: password123
```

#### Operator

```
Email: operator@empresa.com
Password: password123
```

```
Email: laura.diaz@empresa.com
Password: password123
```

### Datos Incluidos

- **15 usuarios**: 2 admins, 5 production managers, 8 operadores
- **79 órdenes de producción**:
  - 52 órdenes normales
  - 27 órdenes urgentes
  - Estados: 53 pending, 24 completed, 2 cancelled
- **356 tareas**:
  - 236 completadas (66.3%)
  - 120 pendientes (33.7%)
  - 58 tareas expiradas (para testing de alertas)
- **205 asignaciones** de operadores a órdenes
- **918 audit logs** completos

---

## 🧪 Tests

El proyecto incluye **269 tests** que cubren:

```bash
# Ejecutar suite completa (local)
bundle exec rspec

# Ejecutar tests en Docker
docker-compose exec web bundle exec rspec

# 269 examples, 0 failures
```

### Tests por Categoría

```bash
# Models (validaciones, relaciones, callbacks)
bundle exec rspec spec/models

# Controllers (CRUD, autenticación, autorización)
bundle exec rspec spec/requests

# Policies (Pundit - permisos por rol)
bundle exec rspec spec/policies

# Background Jobs (Sidekiq)
bundle exec rspec spec/jobs

# Performance (N+1 prevention, query optimization)
bundle exec rspec spec/performance

# Caching (Redis cache behavior)
bundle exec rspec spec/requests/api/v1/monthly_statistics_caching_spec.rb
```

---

## 📚 Documentación API

### Swagger UI Interactivo

- **Railway (remoto)**: https://kiuey-test-api.up.railway.app/api-docs
- **Docker (local)**: http://localhost:3001/api-docs/index.html
- **Local (sin Docker)**: http://localhost:3000/api-docs/index.html

### Documentación Completa

Ver [API.md](API.md) para documentación detallada de todos los endpoints con ejemplos de requests/responses.

### Endpoints Principales

**Autenticación:**

- `POST /api/v1/auth/login` - Login con JWT
- `POST /api/v1/auth/logout` - Logout
- `POST /api/v1/auth/refresh` - Refresh token

**Órdenes de Producción:**

- `GET /api/v1/production_orders` - Listar (con paginación y filtros Ransack)
- `GET /api/v1/production_orders/:id` - Ver detalle
- `POST /api/v1/production_orders` - Crear (con tareas anidadas)
- `PATCH /api/v1/production_orders/:id` - Actualizar
- `DELETE /api/v1/production_orders/:id` - Eliminar

**Reportes y Estadísticas:**

- `GET /api/v1/production_orders/monthly_statistics` - Estadísticas mensuales (cached)
- `GET /api/v1/production_orders/urgent_orders_report` - Reporte de órdenes urgentes
- `GET /api/v1/production_orders/urgent_with_expired_tasks` - Órdenes con tareas vencidas

**Tareas:**

- `POST /api/v1/production_orders/:production_order_id/tasks` - Crear tarea
- `PATCH /api/v1/production_orders/:production_order_id/tasks/:id` - Actualizar
- `PATCH /api/v1/production_orders/:production_order_id/tasks/:id/complete` - Marcar completada
- `DELETE /api/v1/production_orders/:production_order_id/tasks/:id` - Eliminar

**Usuarios:**

- `GET /api/v1/users` - Listar usuarios
- `POST /api/v1/users` - Crear usuario (admin only)
- `PATCH /api/v1/users/:id` - Actualizar usuario

### Ejemplo de Uso

```bash
# 1. Login
curl -X POST http://localhost:3001/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "email": "admin@empresa.com",
    "password": "password123"
  }'

# Response:
# {
#   "token": "eyJhbGciOiJIUzI1NiJ9...",
#   "user": { "id": 1, "name": "Admin Usuario", "role": "admin" }
# }

# 2. Crear orden de producción con tareas
curl -X POST http://localhost:3001/api/v1/production_orders \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "production_order": {
      "type": "NormalOrder",
      "description": "Nueva orden de producción",
      "start_date": "2024-01-15",
      "expected_end_date": "2024-01-30",
      "user_ids": [2, 3],
      "tasks_attributes": [
        {
          "description": "Tarea 1",
          "deadline": "2024-01-20"
        },
        {
          "description": "Tarea 2",
          "deadline": "2024-01-25"
        }
      ]
    }
  }'
```

---

## 📊 Características Técnicas Destacadas

### 🔐 Autenticación y Autorización

- JWT con refresh tokens
- Pundit para autorización granular por rol
- 3 roles: admin, production_manager, operator
- Scopes automáticos según rol y asignaciones

### ⚡ Performance

- Redis cache para estadísticas mensuales
- 7 índices compuestos optimizados
- N+1 query prevention con Bullet
- Eager loading en todas las queries principales
- Query count consistente independiente del dataset size

### 🔄 Background Jobs

- Sidekiq con Redis
- 2 jobs implementados:
  - ExpiredTasksNotificationJob (tareas vencidas)
  - UrgentDeadlineReminderJob (deadlines próximos)
- Scheduling automático con Whenever (cron)

### 📝 Audit Trail

- 918+ audit logs
- Tracking de: created, updated, deleted, assigned, unassigned, status_changed, task_added, task_updated

### 🧪 Testing

- 269 tests con 100% de cobertura de features críticas
- Performance tests
- Policy tests (Pundit)
- Integration tests
- Caching tests

### 🐳 Docker

- Dockerfile optimizado con multi-stage build
- docker-compose.yml con 4 servicios (web, sidekiq, db, redis)
- Health checks configurados para todos los servicios
- Volúmenes persistentes para datos (mysql_data, redis_data, rails_storage, rails_logs)
- Usuario no-root (rails:rails) para seguridad
- Puertos mapeados para evitar conflictos (3001→3000, 3307→3306)
- Migraciones automáticas al iniciar
- Variables de ambiente preconfiguradas con valores por defecto

---

## 🔧 Troubleshooting

### Docker: Container no inicia

**Problema**: El container de web falla al iniciar

**Solución**: Ver logs detallados

```bash
# Ver logs del servicio web
docker-compose logs web

# Verificar estado de todos los servicios
docker-compose ps

# Reiniciar servicios
docker-compose restart

# Reset completo
docker-compose down -v
docker-compose up -d
```

### Docker: "Error: database does not exist"

**Solución**: Las migraciones se ejecutan automáticamente al iniciar, pero si es necesario:

```bash
# Crear base de datos y ejecutar migraciones
docker-compose exec web bundle exec rails db:create db:migrate

# O resetear completamente la base de datos
docker-compose down -v
docker-compose up -d
docker-compose exec web bundle exec rails db:seed
```

### Docker: Port already in use

**Problema**: El puerto 3001 o 3307 ya está en uso

**Solución**: Cambiar el puerto en docker-compose.yml

```bash
# Encontrar proceso usando el puerto
lsof -i :3001

# Matar proceso
kill -9 <PID>

# O cambiar puerto en docker-compose.yml
ports:
  - "3002:3000"  # Cambia 3001 por otro puerto disponible
```

### Error: "Mysql2::Error" (ejecución local)

**Solución**: Verificar que MySQL esté corriendo y las credenciales en `.env` sean correctas.

```bash
# Verificar MySQL
mysql -u root -p -e "SELECT 1"

# Verificar que la base de datos exista
RAILS_ENV=production rails db:create
```

### Error: "Redis::CannotConnectError" (ejecución local)

**Solución**: Verificar que Redis esté corriendo.

```bash
# Iniciar Redis
redis-server

# Verificar conexión
redis-cli ping
# Debería responder: PONG
```

---

## 📞 Soporte

Para preguntas o problemas:

- Ver logs en `log/production.log`
- Ejecutar tests: `bundle exec rspec`
- Consultar [API.md](API.md) para documentación detallada
- Revisar [CHECKLIST.md](CHECKLIST.md) para estado de implementación

---

## 📄 Licencia

Este proyecto es una prueba técnica y no está bajo ninguna licencia específica.
