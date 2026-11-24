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
# As app, the user Passenger runs QUL as: it looks in that user's ~/.passenger. Otherwise every
# app process start compiles it under /tmp (extconf.rb + make in a shell).
RUN setuser app bash -lc 'passenger-config build-native-support' && rm -f /tmp/passenger_native_support-*.log
RUN /pd_build/redis.sh

# Secrets and connection settings come from the Kubernetes Secret at runtime.
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
