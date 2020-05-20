# Borrowed from https://medium.com/carwow-product-engineering/moving-from-heroku-scheduler-to-clockwork-and-sidekiq-7b05f63d0d24
# Helps us managed scheduled taks so that they don't overlap each other mostly
require "sidekiq/api"

module ScheduledTasks
  class ScheduledTask < ApplicationJob
    queue_as :scheduled_tasks

    rescue_from(Exception) do |e|
      # Bugsnag.notify(e)
    end

    def self.perform_unique_later(*args)
      if self.task_already_scheduled?
        logger.warn "Task #{self} already enqueued/running."
        return
      end

      self.perform_later(*args)
    end

    def self.task_already_scheduled?
      job_type = self.to_s
      queue_name = "quotes_site_scheduled_tasks"
      q = Sidekiq::Queue.new(queue_name)
      is_enqueued = q.any? { |j| j["args"][0]["job_class"] == job_type }

      workers = Sidekiq::Workers.new
      is_running = workers.any? do |x, y, work|
        work["queue"] == queue_name &&
        work["payload"]["args"][0]["job_class"] == job_type
      end

      is_enqueued || is_running
    end
  end
end
