# 🚀 Guía de Deployment - Kiuey Test API

Sistema de gestión de órdenes de producción con autenticación JWT, autorización por roles (Pundit), background jobs (Sidekiq), y optimizaciones de performance.

## 📋 Tabla de Contenidos

- [Opciones de Ejecución](#opciones-de-ejecución)
- [Prerequisitos](#prerequisitos)
- [Opción 1: Usar API Remota (ngrok)](#opción-1-usar-api-remota-ngrok)
- [Opción 2: Ejecutar con Docker (Recomendado)](#opción-2-ejecutar-con-docker-recomendado)
- [Opción 3: Ejecutar Localmente](#opción-3-ejecutar-localmente)
- [Opción 4: Deploy en la Nube](#opción-4-deploy-en-la-nube)
- [Datos de Prueba](#datos-de-prueba)
- [Tests](#tests)
- [Documentación API](#documentación-api)

---

## Opciones de Ejecución

### Opción 1: Usar API Remota (ngrok)

**URL del API**: _[URL de ngrok]_

Simplemente configura tu frontend para apuntar a esta URL. La API ya está corriendo con datos de prueba completos.

```javascript
// Ejemplo de configuración en frontend
const API_URL = "https://your-ngrok-url.ngrok.io"
```

**Ventajas:**

- ✅ Sin configuración local necesaria
- ✅ Datos de prueba ya cargados
- ✅ Background jobs funcionando
- ✅ Base de datos completa con 79 órdenes y 356 tareas

---

### Opción 2: Ejecutar con Docker (Recomendado)

**La forma más rápida y sencilla de ejecutar el proyecto completo.**

#### Prerequisitos

- **Docker**: 20.x o superior
- **Docker Compose**: 2.x o superior

#### Instalación con Un Solo Comando

```bash
# 1. Clonar el repositorio
git clone https://github.com/XsKino/production_management-test-api.git
cd production_management-test-api.git

# 2. Generar JWT secret (opcional, hay uno por defecto)
echo "JWT_SECRET_KEY=$(openssl rand -hex 64)" > .env.docker

# 3. Iniciar todos los servicios (MySQL, Redis, Rails, Sidekiq)
docker-compose up -d

# 4. Esperar a que los servicios estén listos (~30 segundos)
docker-compose logs -f web

# Cuando veas "Listening on http://0.0.0.0:3001", la API está lista
```

**API disponible en**: `http://localhost:3001`

#### Cargar Datos de Prueba

```bash
# Ejecutar seeds para crear usuarios, órdenes y tareas
docker-compose exec web bundle exec rails db:seed
```

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

# Reconstruir imágenes (si cambias Gemfile)
docker-compose build
docker-compose up -d
```

#### Verificar Instalación Docker

```bash
# Health check
curl http://localhost:3001/up

# Login test
curl -X POST http://localhost:3001/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"carlos.rodriguez@empresa.com","password":"password123"}'
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

#### Ventajas de Docker

- ✅ **Cero configuración manual** de MySQL y Redis
- ✅ **Entorno reproducible** - funciona igual en todas las máquinas
- ✅ **Aislamiento** - no interfiere con otros proyectos
- ✅ **Cleanup fácil** - `docker-compose down -v` elimina todo
- ✅ **Todos los servicios** en un solo comando

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
git clone https://github.com/tu-usuario/kiuey-test-api.git
cd kiuey-test-api
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

Esto creará:

- 15 usuarios (2 admins, 5 managers, 8 operadores)
- ~79 órdenes de producción
- ~356 tareas
- 58 tareas expiradas para testing
- ~918 audit logs

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
  -d '{"email":"carlos.rodriguez@empresa.com","password":"password123"}'
```

---

### Opción 4: Deploy en la Nube

El proyecto está listo para deploy en plataformas modernas de hosting.

#### Railway (Recomendado)

1. **Crear cuenta en [Railway.app](https://railway.app)**

2. **Crear nuevo proyecto desde GitHub**

3. **Agregar servicios:**

   - MySQL
   - Redis

4. **Configurar variables de ambiente** (usar valores de `.env.example`):

```bash
DATABASE_URL=mysql://user:pass@railway.mysql.com/railway
REDIS_URL=redis://default:pass@railway.redis.com:6379
JWT_SECRET_KEY=generate-with-rails-secret
FORCE_SSL=true
ALLOWED_ORIGINS=https://your-frontend.vercel.app
RAILS_ENV=production
RAILS_LOG_LEVEL=info
```

5. **Deploy automático** se ejecutará

6. **Ejecutar seeds (primera vez)**:

```bash
# En Railway CLI o dashboard
rails db:seed
```

#### Otras Plataformas

- **Heroku**: Agregar addons MySQL y Redis
- **Render**: Similar a Railway
- **Fly.io**: Usar fly.toml (puede requerir configuración adicional)

---

## 🧪 Datos de Prueba

El sistema incluye seeds con datos realistas distribuidos en 4 semanas:

### Usuarios de Prueba

#### Admin

```
Email: carlos.rodriguez@empresa.com
Password: password123
```

```
Email: maria.gonzalez@empresa.com
Password: password123
```

#### Production Manager

```
Email: roberto.silva@empresa.com
Password: password123
```

```
Email: patricia.moreno@empresa.com
Password: password123
```

#### Operator

```
Email: miguel.torres@empresa.com
Password: password123
```

```
Email: ana.lopez@empresa.com
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

El proyecto incluye 269 tests que cubren:

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

### Documentación Completa

Ver [API.md](API.md) para documentación detallada de todos los endpoints.

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

### Ejemplo de Request

```bash
# 1. Login
curl -X POST http://localhost:3000/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "email": "carlos.rodriguez@empresa.com",
    "password": "password123"
  }'

# Response:
# {
#   "token": "eyJhbGciOiJIUzI1NiJ9...",
#   "user": { "id": 1, "name": "Carlos Rodríguez", "role": "admin" }
# }

# 2. Listar órdenes (usar token del login)
curl -X GET http://localhost:3000/api/v1/production_orders \
  -H "Authorization: Bearer eyJhbGciOiJIUzI1NiJ9..."

# 3. Crear orden con tareas
curl -X POST http://localhost:3000/api/v1/production_orders \
  -H "Authorization: Bearer eyJhbGciOiJIUzI1NiJ9..." \
  -H "Content-Type: application/json" \
  -d '{
    "production_order": {
      "type": "NormalOrder",
      "start_date": "2025-11-25",
      "expected_end_date": "2025-12-05",
      "tasks_attributes": [
        {
          "description": "Cortar material",
          "expected_end_date": "2025-11-27"
        },
        {
          "description": "Ensamblar piezas",
          "expected_end_date": "2025-11-30"
        }
      ],
      "user_ids": [3, 4]
    }
  }'
```

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

### Docker: Port 3001 already in use

**Problema**: El puerto 3001 ya está en uso por otro servicio

**Solución**: Detener el proceso o cambiar el puerto en docker-compose.yml

```bash
# Encontrar proceso usando el puerto 3001
lsof -i :3001

# Matar proceso
kill -9 <PID>

# O cambiar puerto en docker-compose.yml (línea 76)
ports:
  - "3002:3000"  # Cambia 3001 por otro puerto disponible
```

### Docker: Port 3307 (MySQL) already in use

**Problema**: El puerto 3307 ya está en uso

**Solución**: Cambiar el puerto de MySQL en docker-compose.yml

```bash
# En docker-compose.yml, cambiar línea 16:
ports:
  - "3308:3306"  # Usa otro puerto local disponible
```

### Error: "PG::ConnectionBad" o "Mysql2::Error" (ejecución local)

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
# Debe responder: PONG
```

### Error: "Bullet::Notification::UnoptimizedQueryError" en tests

**Solución**: Este error es intencional. Bullet detecta queries N+1. Si aparece, significa que hay un problema de performance que debe ser corregido en el código, no deshabilitando Bullet.

### Frontend no puede conectarse (CORS)

**Solución**: Verificar variable `ALLOWED_ORIGINS` en `.env`.

```bash
# Para desarrollo local
ALLOWED_ORIGINS=http://localhost:3000,http://localhost:3001

# Para producción
ALLOWED_ORIGINS=https://tu-frontend.vercel.app
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

- Dockerfile simplificado y optimizado
- docker-compose.yml con 4 servicios (web, sidekiq, db, redis)
- Health checks configurados para todos los servicios
- Volúmenes persistentes para datos (mysql_data, redis_data, rails_storage, rails_logs)
- Usuario no-root (rails:rails) para seguridad
- Puertos mapeados para evitar conflictos (3001→3000, 3307→3306)
- Migraciones automáticas al iniciar
- Variables de ambiente preconfiguradas con valores por defecto

---

## 📞 Soporte

Para preguntas o problemas durante la evaluación:

- Ver logs en `log/production.log`
- Ejecutar tests: `bundle exec rspec`
- Consultar [API.md](API.md) para documentación detallada
- Revisar [CHECKLIST.md](CHECKLIST.md) para estado de implementación

---

## 📄 Licencia

Este proyecto es una prueba técnica y no está bajo ninguna licencia específica.
