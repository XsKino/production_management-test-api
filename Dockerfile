# Dockerfile para Kiuey Test API
# Optimizado para prueba técnica - Simple y funcional

FROM ruby:3.3.6-slim

# Instalar dependencias del sistema necesarias
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y \
    build-essential \
    git \
    default-libmysqlclient-dev \
    pkg-config \
    curl \
    default-mysql-client \
    wget && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

# Crear usuario no-root para seguridad
RUN groupadd --system --gid 1000 rails && \
    useradd rails --uid 1000 --gid 1000 --create-home --shell /bin/bash

# Configurar directorio de trabajo
WORKDIR /rails

# Copiar Gemfile y Gemfile.lock
COPY Gemfile Gemfile.lock ./

# Instalar gems como root (necesario para escribir en /usr/local/bundle)
RUN bundle config set --local without 'development test' && \
    bundle install --jobs 4 --retry 3

# Copiar código de la aplicación
COPY --chown=rails:rails . .

# Cambiar a usuario no-root
USER rails

# Variables de entorno
ENV RAILS_ENV="production"

# Exponer puerto 3000
EXPOSE 3000

# Health check (Railway usa PORT dinámico)
HEALTHCHECK --interval=30s --timeout=3s --start-period=40s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://localhost:${PORT:-3000}/up || exit 1

# Comando por defecto: iniciar Rails server
# Railway provee PORT dinámicamente, usar 3000 como fallback
CMD ["sh", "-c", "bundle exec rails db:prepare && bundle exec rails server -b 0.0.0.0 -p ${PORT:-3000}"]
