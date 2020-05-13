# Set up jobs and allow us to capture exceptions in them
# Borrowed from https://medium.com/carwow-product-engineering/moving-from-heroku-scheduler-to-clockwork-and-sidekiq-7b05f63d0d24

require File.expand_path("../config/boot",        __FILE__)
require File.expand_path("../config/environment", __FILE__)
require "clockwork"

module Clockwork
  every(30.seconds, "Caching: Warm caches") do
    ScheduledTasks::Caching::WarmCacheJob.perform_unique_later
  end

  error_handler do |error|
    puts "Error: #{error}"
  end
end
