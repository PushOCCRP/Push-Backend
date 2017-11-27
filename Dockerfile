FROM ruby:2.4-stretch

RUN apt-get update
RUN apt-get -y install apt-transport-https ca-certificates

RUN wget https://dl.yarnpkg.com/debian/pubkey.gpg
RUN apt-key add pubkey.gpg

RUN echo "deb https://dl.yarnpkg.com/debian/ stable main" | tee /etc/apt/sources.list.d/yarn.list
RUN curl --silent --location https://deb.nodesource.com/setup_8.x | bash -

RUN apt-get install -y build-essential libpq-dev nodejs yarn

RUN gem install bundler
RUN RAILS_ENV=production
WORKDIR /push
CMD ["rails", "s", "-b", "0.0.0.0", "--production", "-p", "80"]
