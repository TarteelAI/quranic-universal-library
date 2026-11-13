FROM phusion/passenger-customizable:3.2.3

# set correct environment variables
ENV HOME /root

# use baseimage-docker's init process
CMD ["/sbin/my_init"]

# Install Node 24 LTS before ruby setup — the phusion ruby script (install_ruby_utils.sh)
# checks for /etc/apt/sources.list.d/nodesource.list and skips its own Node installation
# if present. Without this, phusion installs its default Node 22, whose npm is broken
# (missing promise-retry).
RUN curl -fsSL https://deb.nodesource.com/setup_24.x | bash - && \
    apt-get install -y --no-install-recommends nodejs && \
    rm -rf /var/lib/apt/lists/*
RUN corepack enable

# customizing passenger-customizable image
# rvm builds Ruby from source and keeps the build tree; gems compile against
# the headers under /usr/local/rvm/rubies, so the tree is not needed at runtime.
# The script also installs rustc (plus LLVM) only to compile YJIT, and leaves it behind.
RUN /pd_build/ruby-3.3.*.sh && \
    apt-get remove -y rustc && apt-get autoremove -y && \
    rm -rf /usr/local/rvm/src /usr/local/rvm/archives /var/lib/apt/lists/*
RUN bash -lc 'rvm --default use ruby-3.3.13'
RUN /pd_build/redis.sh

# set environment variables
ARG SECRET_KEY_BASE
ARG RAILS_MASTER_KEY
ARG SENTRY_DSN
ARG LOKALISE_API_KEY
ARG LOKALISE_PROJECT_ID

# QUL Quran content database
ARG QUL_QURAN_CONTENT_DB_NAME
ARG QUL_QURAN_CONTENT_DB_USERNAME
ARG QUL_QURAN_CONTENT_DB_PASSWORD
ARG QUL_QURAN_CONTENT_DB_HOST
ARG QUL_QURAN_CONTENT_DB_PORT

# QUL CMS content database
ARG QUL_CMS_CONTENT_DB_NAME
ARG QUL_CMS_CONTENT_DB_USERNAME
ARG QUL_CMS_CONTENT_DB_PASSWORD
ARG QUL_CMS_CONTENT_DB_HOST
ARG QUL_CMS_CONTENT_DB_PORT

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

# QUL Quran content database
ENV QUL_QURAN_CONTENT_DB_NAME=${QUL_QURAN_CONTENT_DB_NAME}
ENV QUL_QURAN_CONTENT_DB_USERNAME=${QUL_QURAN_CONTENT_DB_USERNAME}
ENV QUL_QURAN_CONTENT_DB_PASSWORD=${QUL_QURAN_CONTENT_DB_PASSWORD}
ENV QUL_QURAN_CONTENT_DB_HOST=${QUL_QURAN_CONTENT_DB_HOST}
ENV QUL_QURAN_CONTENT_DB_PORT=${QUL_QURAN_CONTENT_DB_PORT}

# QUL CMS content database
ENV QUL_CMS_CONTENT_DB_NAME=${QUL_CMS_CONTENT_DB_NAME}
ENV QUL_CMS_CONTENT_DB_USERNAME=${QUL_CMS_CONTENT_DB_USERNAME}
ENV QUL_CMS_CONTENT_DB_PASSWORD=${QUL_CMS_CONTENT_DB_PASSWORD}
ENV QUL_CMS_CONTENT_DB_HOST=${QUL_CMS_CONTENT_DB_HOST}
ENV QUL_CMS_CONTENT_DB_PORT=${QUL_CMS_CONTENT_DB_PORT}

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

# sidekiq
RUN mkdir -p /etc/service/sidekiq
ADD docker/sidekiq.run /etc/service/sidekiq/run
RUN chmod +x /etc/service/sidekiq/run

# logrotate
COPY docker/nginx.logrotate.conf /etc/logrotate.d/nginx
RUN cp /etc/cron.daily/logrotate /etc/cron.hourly

RUN apt-get update && \
    apt-get install -y --no-install-recommends curl build-essential autoconf automake ffmpeg && \
    rm -rf /var/lib/apt/lists/*

# setup gems
WORKDIR /tmp
ADD Gemfile Gemfile
ADD Gemfile.lock Gemfile.lock
RUN bundle install && rm -rf "$(gem env gemdir)"/cache/*.gem

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

# install JS deps inside the image
RUN yarn install --frozen-lockfile && yarn cache clean

# precompile assets
RUN SECRET_KEY_BASE_DUMMY=1 ./bin/rails assets:precompile
RUN SECRET_KEY_BASE_DUMMY=1 ./bin/rails assets:precompile

# pg_dump
RUN apt-get update && apt-get install -y --no-install-recommends wget \
    && wget --quiet -O /etc/apt/keyrings/pgdg.asc https://www.postgresql.org/media/keys/ACCC4CF8.asc \
    && echo "deb [signed-by=/etc/apt/keyrings/pgdg.asc] http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list \
    && apt-get update \
    && apt-get install -y --no-install-recommends postgresql-client-16 \
    && rm -rf /var/lib/apt/lists/*

# cleanup apt
RUN apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# write permissions to tmp
RUN chown -R app tmp

# ... and to production.log
RUN chown app log/production.log

# expose port 3000
EXPOSE 3000
