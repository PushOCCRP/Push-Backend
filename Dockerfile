FROM ruby:2.2.3
RUN apt-get update -qq && apt-get install -y build-essential libpq-dev nodejs
RUN gem install bundler
WORKDIR /push
CMD ["rails", "s", "-b", "0.0.0.0"]
