FROM ruby:2.1.6
MAINTAINER Maarten Trompper <m.f.a.trompper@uva.nl>

# throw errors if Gemfile has been modified since Gemfile.lock
RUN bundle config --global frozen 1

RUN mkdir -p /usr/src/app
ADD . /usr/src/app
WORKDIR /usr/src/app

RUN bundle install

VOLUME /usr/src/app/md

RUN git clone git@github.com:statengeneraal/tools-github-bwb.git /usr/src/app/md

CMD ["ruby", "./git_update.rb"]
