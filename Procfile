web: bundle exec rails db:prepare && bundle exec rails server -b 0.0.0.0 -p ${PORT:-3000}
worker: bundle exec sidekiq -C config/sidekiq.yml
