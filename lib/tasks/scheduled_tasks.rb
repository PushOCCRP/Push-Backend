# Borrowed from https://medium.com/carwow-product-engineering/moving-from-heroku-scheduler-to-clockwork-and-sidekiq-7b05f63d0d24
# Allows us to run scheduled tasks from the command line for testing and maintence

namespace :scheduled_tasks do
  require "./app/jobs/scheduled_tasks/scheduled_task"
  Dir[File.join(".", "app/jobs/scheduled_tasks/**/*.rb")].each { |f| require f }

  classes = ObjectSpace.each_object(Class).select { |klass| klass < ScheduledTasks::ScheduledTask }

  classes.each do |klass|
    class_name = klass.to_s
    task_name = class_name.gsub("ScheduledTasks::", "").gsub("::", ":").underscore

    desc "Runs #{class_name}"
    task task_name => :environment do
      puts "Executing job #{class_name}"
      klass.perform_now
    end
  end
end
