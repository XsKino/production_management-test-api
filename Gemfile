source "https://rubygems.org"

gem "rails", "~> 8.1.1"
gem "mysql2", "~> 0.5"
gem "puma", ">= 5.0"

# Autenticación
gem "bcrypt", "~> 3.1.7"

# Autorización
gem "pundit"

# Filtrado y Paginación
gem "ransack"
gem "kaminari"

# Background Jobs
gem "sidekiq"
gem "redis"

# Windows timezone
gem "tzinfo-data", platforms: %i[ windows jruby ]

# Performance
gem "bootsnap", require: false

group :development, :test do
  gem "debug", platforms: %i[ mri windows ], require: "debug/prelude"
  gem 'dotenv-rails'

  # Testing
  gem "rspec-rails"
  gem "factory_bot_rails"
  gem "faker"
  gem "shoulda-matchers"
  gem "pundit-matchers"
  gem "database_cleaner-active_record"
end
