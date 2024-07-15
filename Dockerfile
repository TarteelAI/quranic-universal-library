FROM phusion/passenger-customizable:2.5.0

# set correct environment variables
ENV HOME /root

# use baseimage-docker's init process
CMD ["/sbin/my_init"]

# customizing passenger-customizable image
RUN /pd_build/ruby-3.0.*.sh
RUN bash -lc 'rvm --default use ruby-3.0.5'
RUN /pd_build/redis.sh

ENV RAILS_ENV production
ENV NODE_ENV production
ENV RAILS_SERVE_STATIC_FILES true

# redis
ENV REDIS_TOGO_URL "redis://127.0.0.1:6379"
RUN rm -f /etc/service/redis/down

# nginx
RUN rm /etc/service/nginx/down
RUN rm /etc/nginx/sites-enabled/default
ADD docker/qul.tarteel.ai /etc/nginx/sites-enabled/qul.tarteel.ai
ADD docker/misc-env.conf /etc/nginx/main.d/misc-env.conf
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

ARG SECRET_KEY_BASE
ARG RAILS_MASTER_KEY
ENV SECRET_KEY_BASE=${SECRET_KEY_BASE}
ENV RAILS_MASTER_KEY=${RAILS_MASTER_KEY}

RUN echo "$SECRET_KEY_BASE ===================="
RUN echo $RAILS_MASTER_KEY
RUN echo "$RAILS_MASTER_KEY  ===================="
RUN echo $RAILS_MASTER_KEY

# precompile assets
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
