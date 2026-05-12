# syntax=docker/dockerfile:1
#
# Production Dockerfile for QUL.
#
# Single-process image. The same image is used for two container roles:
#   web:    CMD ["./bin/thrust", "./bin/rails", "server"]   (default)
#   worker: CMD ["./bin/start-sidekiq"]
#
# External services expected at runtime (set via env vars):
#   DATABASE_URL (or QURAN_API_DB_* / CMS_DB_* groups), REDIS_URL,
#   RAILS_MASTER_KEY, plus the SMTP/S3/Sentry/etc. vars used by the app.

ARG RUBY_VERSION=3.3.3
FROM docker.io/library/ruby:$RUBY_VERSION-slim AS base

WORKDIR /rails

# Runtime OS packages
RUN apt-get update -qq && \
    apt-get install -y --no-install-recommends wget gnupg lsb-release curl ca-certificates && \
    echo "deb http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list && \
    wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | apt-key add - && \
    apt-get update -qq && \
    apt-get install --no-install-recommends -y \
      libjemalloc2 \
      libvips \
      postgresql-client-16 \
      ffmpeg \
      git && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

ENV RAILS_ENV="production" \
    BUNDLE_DEPLOYMENT="1" \
    BUNDLE_PATH="/usr/local/bundle" \
    BUNDLE_WITHOUT="development:test" \
    TMPDIR="/rails/tmp" \
    LD_PRELOAD="libjemalloc.so.2"

# --- Build stage ---------------------------------------------------------------
FROM base AS build

RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y \
      build-essential \
      autoconf \
      automake \
      libpq-dev \
      node-gyp \
      pkg-config \
      python-is-python3 && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

# Node + Yarn
ARG NODE_VERSION=20.18.0
ARG YARN_VERSION=1.22.22
ENV PATH=/usr/local/node/bin:$PATH
RUN curl -sL https://github.com/nodenv/node-build/archive/master.tar.gz | tar xz -C /tmp/ && \
    /tmp/node-build-master/bin/node-build "${NODE_VERSION}" /usr/local/node && \
    npm install -g yarn@$YARN_VERSION && \
    rm -rf /tmp/node-build-master

# Install gems
COPY Gemfile Gemfile.lock ./
RUN bundle install --jobs $(nproc) && \
    rm -rf ~/.bundle/ "${BUNDLE_PATH}"/ruby/*/cache "${BUNDLE_PATH}"/ruby/*/bundler/gems/*/.git && \
    bundle exec bootsnap precompile --gemfile

# Install JS deps
COPY package.json yarn.lock ./
RUN yarn install --frozen-lockfile

# Application code
COPY . .

# Precompile bootsnap for faster boot
RUN bundle exec bootsnap precompile app/ lib/

# Build JS/CSS bundles explicitly so any bundler failure (esbuild, sass, tailwind)
# fails the Docker layer with a clear error, then fingerprint via sprockets.
RUN yarn build
RUN yarn build:css
RUN SECRET_KEY_BASE_DUMMY=1 bundle exec rails assets:precompile

# Drop node_modules from the final image — they are only needed for the build
RUN rm -rf node_modules

# --- Final stage --------------------------------------------------------------
FROM base

COPY --from=build "${BUNDLE_PATH}" "${BUNDLE_PATH}"
COPY --from=build /rails /rails

# Non-root runtime user
RUN groupadd --system --gid 1000 rails && \
    useradd rails --uid 1000 --gid 1000 --create-home --shell /bin/bash && \
    mkdir -p tmp/cache tmp/pids tmp/sockets tmp/storage tmp/qr tmp/database_backups && \
    chown -R rails:rails db log storage tmp && \
    chmod -R 775 tmp
USER 1000:1000

ENTRYPOINT ["/rails/bin/docker-entrypoint"]

# Web server by default; override CMD for the sidekiq container.
EXPOSE 80
CMD ["./bin/thrust", "./bin/rails", "server"]
