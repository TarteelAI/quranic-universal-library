FROM phusion/passenger-customizable:3.0.6

# set correct environment variables
ENV HOME /root

# use baseimage-docker's init process
CMD ["/sbin/my_init"]

# customizing passenger-customizable image
RUN /pd_build/ruby-3.3.*.sh
RUN bash -lc 'rvm --default use ruby-3.3.3'
RUN /pd_build/redis.sh

# Nodejs
RUN /pd_build/nodejs.sh 20

# set environment variables
ARG SECRET_KEY_BASE
ARG RAILS_MASTER_KEY
ARG SENTRY_DSN
ARG LOKALISE_API_KEY
ARG LOKALISE_PROJECT_ID

# Quran API db
ARG QURAN_API_DB_NAME
ARG QURAN_API_DB_USERNAME
ARG QURAN_API_DB_PASSWORD
ARG QURAN_API_DB_HOST
ARG QURAN_API_DB_PORT

# CMS db
ARG CMS_DB_NAME
ARG CMS_DB_USERNAME
ARG CMS_DB_PASSWORD
ARG CMS_DB_HOST
ARG CMS_DB_PORT

# Storage
ARG DB_BACK_BUCKET
ARG AWS_ACCESS_KEY
ARG AWS_ACCESS_KEY_SECRET
ARG AWS_BUCKET
ARG ALLOW_PUBLIC_EXPORT

# QUL exported file storage
ARG QUL_STORAGE_ACCESS_KEY
ARG QUL_STORAGE_ACCESS_KEY_SECRET
ARG QUL_STORAGE_BUCKET
ARG QUL_STORAGE_PUBLIC_EXPORT
ARG QUL_STORAGE_ENDPOINT
ARG QUL_STORAGE_REGION

# SMTP
ARG SMTP_ADDRESS
ARG SMTP_PORT
ARG SMTP_USERNAME
ARG SMTP_PASSWORD
ARG MAILER_SENDER
ARG ADMIN_USER_EMAIL

# Cloudflare
ARG CLOUDFLARE_API_KEY
ARG CLOUDFLARE_ZONE_ID

ENV SECRET_KEY_BASE=${SECRET_KEY_BASE}
ENV RAILS_MASTER_KEY=${RAILS_MASTER_KEY}

ENV SENTRY_DSN=${SENTRY_DSN}
ENV LOKALISE_API_KEY=${LOKALISE_API_KEY}
ENV LOKALISE_PROJECT_ID=${LOKALISE_PROJECT_ID}

# Quran API db
ENV QURAN_API_DB_NAME=${QURAN_API_DB_NAME}
ENV QURAN_API_DB_USERNAME=${QURAN_API_DB_USERNAME}
ENV QURAN_API_DB_PASSWORD=${QURAN_API_DB_PASSWORD}
ENV QURAN_API_DB_HOST=${QURAN_API_DB_HOST}
ENV QURAN_API_DB_PORT=${QURAN_API_DB_PORT}

# CMS db
ENV CMS_DB_NAME=${CMS_DB_NAME}
ENV CMS_DB_USERNAME=${CMS_DB_USERNAME}
ENV CMS_DB_PASSWORD=${CMS_DB_PASSWORD}
ENV CMS_DB_HOST=${CMS_DB_HOST}
ENV CMS_DB_PORT=${CMS_DB_PORT}

# Storage
ENV DB_BACK_BUCKET=${DB_BACK_BUCKET}
ENV AWS_ACCESS_KEY=${AWS_ACCESS_KEY}
ENV AWS_ACCESS_KEY_SECRET=${AWS_ACCESS_KEY_SECRET}
ENV AWS_BUCKET=${AWS_BUCKET}
ENV ALLOW_PUBLIC_EXPORT=${ALLOW_PUBLIC_EXPORT}

# QUL exported file storage
ENV QUL_STORAGE_ACCESS_KEY=${QUL_STORAGE_ACCESS_KEY}
ENV QUL_STORAGE_ACCESS_KEY_SECRET=${QUL_STORAGE_ACCESS_KEY_SECRET}
ENV QUL_STORAGE_BUCKET=${QUL_STORAGE_BUCKET}
ENV QUL_STORAGE_PUBLIC_EXPORT=${QUL_STORAGE_PUBLIC_EXPORT}
ENV QUL_STORAGE_ENDPOINT=${QUL_STORAGE_ENDPOINT}
ENV QUL_STORAGE_REGION=${QUL_STORAGE_REGION}

# SMTP
ENV SMTP_ADDRESS=${SMTP_ADDRESS}
ENV SMTP_PORT=${SMTP_PORT}
ENV SMTP_USERNAME=${SMTP_USERNAME}
ENV SMTP_PASSWORD=${SMTP_PASSWORD}
ENV MAILER_SENDER=${MAILER_SENDER}
ENV ADMIN_USER_EMAIL=${ADMIN_USER_EMAIL}

# Cloudflare
ENV CLOUDFLARE_API_KEY=${CLOUDFLARE_API_KEY}
ENV CLOUDFLARE_ZONE_ID=${CLOUDFLARE_ZONE_ID}

ENV RAILS_ENV production
ENV NODE_ENV production
ENV RAILS_SERVE_STATIC_FILES true


# redis
ENV REDIS_URL "redis://127.0.0.1:6379"
RUN rm -f /etc/service/redis/down

# memcached
RUN /pd_build/memcached.sh
RUN rm -f /etc/service/memcached/down

# nginx
RUN rm /etc/service/nginx/down
RUN rm /etc/nginx/sites-enabled/default
ADD docker/qul.tarteel.ai /etc/nginx/sites-enabled/qul.tarteel.ai
ADD docker/gzip.conf /etc/nginx/conf.d/gzip.conf

# logrotate
COPY docker/nginx.logrotate.conf /etc/logrotate.d/nginx
RUN cp /etc/cron.daily/logrotate /etc/cron.hourly

RUN apt-get update
RUN apt-get install -y curl build-essential autoconf automake ffmpeg

# setup yarn
RUN /pd_build/nodejs.sh
RUN corepack enable

# setup gems
WORKDIR /tmp
ADD Gemfile Gemfile
ADD Gemfile.lock Gemfile.lock
RUN bundle install

# setup the app
RUN mkdir /home/app/qul
ADD . /home/app/qul/

WORKDIR /home/app/qul
RUN mkdir -p tmp
RUN mkdir -p log && touch log/production.log
RUN chown -R app log
RUN chown -R app public
RUN chown app Gemfile
RUN chown app Gemfile.lock
RUN mkdir -p /var/log/nginx/qul.tarteel.ai

# precompile assets
RUN SECRET_KEY_BASE_DUMMY=1 ./bin/rails assets:precompile

#TODO: fix this, sprockets can't find the compiled assets.
# Compiling twice seems to be working
RUN SECRET_KEY_BASE_DUMMY=1 ./bin/rails assets:precompile

# pg_dump
RUN apt-get install -y wget
RUN sh -c 'echo "deb http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list'
RUN wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | apt-key add -
RUN apt-get --allow-releaseinfo-change update
RUN apt-get install -y postgresql-client-14

# cleanup apt
RUN apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# write permissions to tmp
RUN chown -R app tmp

# ... and to production.log
RUN chown app log/production.log

# expose port 3000
EXPOSE 3000
