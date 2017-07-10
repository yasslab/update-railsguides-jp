FROM ruby:2.4.1-alpine

# Set up JST time zone
RUN apk --update add tzdata && \
    cp /usr/share/zoneinfo/Asia/Tokyo /etc/localtime && \
    apk del tzdata && \
    rm -rf /var/cache/apk/*

# to run import-upstream
RUN apk --update add git openssh bash curl \
    build-base ruby-dev postgresql-dev

# to send pull request
RUN gem install octokit sinatra faraday sequel pg

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
COPY create_database.rb /usr/src

# Set travis-ci webhook handling server
COPY config.ru /usr/src/config.ru
COPY server.rb /usr/src/server.rb

# Set working dir
WORKDIR /usr/src

# Set up base repository & upstream
RUN cd /usr/src && \
    git clone https://github.com/yasslab/railsguides.jp.git && \
    cd railsguides.jp && \
    git remote add upstream https://github.com/rails/rails.git

# run travis-ci webhook handling server
CMD rackup -p $PORT -o 0.0.0.0

# Run image as a non-root user
# ref: https://devcenter.heroku.com/articles/container-registry-and-runtime#run-the-image-as-a-non-root-user
RUN adduser -D myuser
USER myuser
