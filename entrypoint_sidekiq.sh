#!/bin/bash

echo ""
echo "Running Bundler... 🎁"

bundle config build.nokogiri --use-system-libraries
bundle install --path vendor/bundle

echo ""
echo "Starting Sidekiq...⚙️🦵"

exec $@
