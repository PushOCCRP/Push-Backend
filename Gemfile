# frozen_string_literal: true

ruby "2.5.7"

source "https://rubygems.org"

# Bundle edge Rails instead: gem 'rails', github: 'rails/rails'
gem "rails", "~>5.2.4"
# Use SCSS for stylesheets
gem "sass-rails"
# Use Uglifier as compressor for JavaScript assets
# gem "uglifier"
# Use CoffeeScript for .coffee assets and views
# gem "coffee-rails"
# See https://github.com/rails/execjs#readme for more supported runtimes
# gem 'therubyracer', platforms: :ruby

# Use jquery as the JavaScript library
# gem "jquery-rails"
# Turbolinks makes following links in your web application faster. Read more: https://github.com/rails/turbolinks
gem "turbolinks"
# Build JSON APIs with ease. Read more: https://github.com/rails/jbuilder
gem "jbuilder"
# bundle exec rake doc:rails generates the API under doc/api.
gem "sdoc"

# Filemagic to check content type of images or whatever we need
gem "ruby-filemagic"

# Postgres, for databases
gem "pg"

# Rake, because it's what Ruby and Rails uses for all automation.
gem "rake"

# Elasticsearch integration
gem "dalli"

# Figaro is used to insure that environment variables exist on boot instead of silently failing later
gem "figaro"

# Not sure
gem "htmlentities"

# For making HTTP calls
gem "httparty"

# Memcache is used for caching our requests and such
gem "memcachier"

# Binding for ImageMagick for manipulating images, resizing etc.
gem "mini_magick"

# Nokogiri is an XML/HTML parser used for cleaning up the html
gem "nokogiri"

# The server we use
gem "puma"

# Not sure
gem "rails_12factor"

# Not Sure
gem "addressable"

# Authentication gem to handle users
gem "devise"

# Unsure
gem "rails-settings-cached", git: "https://github.com/huacnlee/rails-settings-cached", branch: "0.x"

# Unsure
gem "fcm"

# Unsure.
gem "rufus-scheduler"

# Rubocop is used as a linter
gem "rubocop", "~> 0.78.0", require: false
# Use Rails's default rubocop rulse
gem "rubocop-rails_config"

# Use ActiveModel has_secure_password
# gem 'bcrypt', '~> 3.1.7'

# We're using modern Webpacker to handle our Javascript assets now
gem "webpacker", "~> 4"

# Sprockets for asset management
gem "sprockets-rails"

group :development do
  # Access an IRB console on exception pages or by using <%= console %> in views
  gem "web-console"
end

group :development, :test do
  # Call 'byebug' anywhere in the code to stop execution and get a debugger console
  gem "byebug"

  # Spring speeds up development by keeping your application running in the background. Read more: https://github.com/rails/spring
  gem "spring"

  # Allow connections for the webpack-dev-server
  gem "rack-cors", require: "rack/cors"
end
