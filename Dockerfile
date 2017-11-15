FROM ruby:2.4.1-alpine

RUN apk update && apk upgrade && \
    apk add --no-cache bash git openssh build-base
RUN apk add --no-cache postgresql-dev

RUN gem install bundler -v 1.16.0

WORKDIR /opt/phobos_db_checkpoint

ADD Gemfile Gemfile
ADD phobos_db_checkpoint.gemspec phobos_db_checkpoint.gemspec
ADD lib/phobos_db_checkpoint/version.rb lib/phobos_db_checkpoint/version.rb

RUN bundle config build.pg --with-pg-config=/usr/pgsql-9.6/bin/pg_config
RUN bundle install

ADD . .
