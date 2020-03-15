# frozen_string_literal: true

# Load the Rails application.
require File.expand_path("application", __dir__)

# Initialize the Rails application.
Rails.application.initialize!

Rails.logger = Le.new("8384a90e-51ca-4d50-8a6b-35d744b27fdb", debug: true, local: true)
