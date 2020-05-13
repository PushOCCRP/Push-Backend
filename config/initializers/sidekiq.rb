require "sidekiq/web"

Concurrent.use_stdlib_logger(Logger::DEBUG)

Sidekiq.configure_client do |config|
  config.redis = { url: ENV["REDIS_URL"] }
end

Sidekiq.configure_server do |config|
  config.redis = { url: ENV["REDIS_URL"] }
end

Sidekiq.default_worker_options = { "backtrace" => true }
