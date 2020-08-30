FROM ruby:2.6.6-stretch

RUN apt-get update
RUN apt-get -y install apt-transport-https ca-certificates libmagic-dev

RUN wget https://dl.yarnpkg.com/debian/pubkey.gpg
RUN apt-key add pubkey.gpg

RUN echo "deb https://dl.yarnpkg.com/debian/ stable main" | tee /etc/apt/sources.list.d/yarn.list
RUN curl --silent --location https://deb.nodesource.com/setup_14.x | bash -

RUN apt-get install -y build-essential libpq-dev nodejs yarn

# This is for a work around in SEOWorks where some image's dimensions are returned as null
# We don't want that to happen, so we need to determine them ourselves
# This can be removed later if we get that bug fixed
RUN apt-get install -y libmagickwand-dev

RUN gem install bundler
RUN RAILS_ENV=development
WORKDIR /push
CMD ["rails", "s", "-b", "0.0.0.0", "-p", "80"]
