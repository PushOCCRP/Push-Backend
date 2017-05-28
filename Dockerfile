FROM ruby:2.2.7
RUN apt-get update -qq && apt-get install -y build-essential libpq-dev nodejs
RUN gem install bundler
RUN RAILS_ENV=production
WORKDIR /push
CMD ["rails", "s", "-b", "0.0.0.0", "--production", "-p", "80"]
