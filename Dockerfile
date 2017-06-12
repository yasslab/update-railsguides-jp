FROM ruby:2.4.1-alpine

# throw errors if Gemfile has been modified since Gemfile.lock
RUN bundle config --global frozen 1

# Set up JST time zone
RUN apk --update add tzdata && \
    cp /usr/share/zoneinfo/Asia/Tokyo /etc/localtime && \
    apk del tzdata && \
    rm -rf /var/cache/apk/*

# to run import-upstream
RUN apk --update add git openssh bash

# to download hub
RUN apk --no-cache add openssl

# to send pull request
RUN gem install octokit

# Set up github config
RUN mkdir -p /usr/src/.ssh/
COPY id_rsa /usr/src/.ssh/
RUN chmod 600 /usr/src/.ssh/id_rsa

# Set up login & password
COPY .netrc /usr/src

# Set auto merge scripts
COPY import-upstream /usr/src
COPY create_pull_request.rb /usr/src
COPY notify_message.html.erb /usr/src

# Set working dir
WORKDIR /usr/src

# Set up base repository & upstream
RUN cd /usr/src && \
    git clone https://github.com/yasslab/railsguides.jp.git && \
    cd railsguides.jp && \
    git remote add upstream https://github.com/rails/rails.git

# Run image as a non-root user
# ref: https://devcenter.heroku.com/articles/container-registry-and-runtime#run-the-image-as-a-non-root-user
RUN adduser -D myuser
USER myuser
