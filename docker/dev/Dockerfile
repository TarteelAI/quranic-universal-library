FROM ruby:3.3.3-slim

# System dependencies for native gems and tools
RUN apt-get update -qq && \
    apt-get install -y --no-install-recommends \
      build-essential \
      libpq-dev \
      libvips-dev \
      ffmpeg \
      hunspell libhunspell-dev \
      protobuf-compiler libprotobuf-dev \
      curl wget unzip \
      git \
      postgresql-client \
    && rm -rf /var/lib/apt/lists/*

# Install Node.js 20
RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - && \
    apt-get install -y --no-install-recommends nodejs && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Bundler config: install gems into vendor/bundle (mounted volume)
RUN gem install bundler
ENV BUNDLE_PATH=/app/vendor/bundle
ENV BUNDLE_BIN=/app/vendor/bundle/bin
ENV PATH="/app/vendor/bundle/bin:/app/bin:${PATH}"

ENTRYPOINT ["/app/docker/dev/entrypoint.sh"]
