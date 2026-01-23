# docker/linux/language-packs/ruby/Dockerfile.ruby
# Ruby language pack for GitHub Actions runners using rbenv
# Size: ~150MB (adds to base ~300MB = ~450MB total)

FROM gh-runner:linux-base AS ruby-pack

# Switch to root for package installation
USER root

# Prevent interactive prompts
ENV DEBIAN_FRONTEND=noninteractive

# Install Ruby build dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    libssl-dev \
    libreadline-dev \
    zlib1g-dev \
    libyaml-dev \
    libgmp-dev \
    libffi-dev \
    libgdbm-dev \
    libncurses5-dev \
    libncursesw5-dev \
    libsqlite3-dev \
    libcurl4-openssl-dev \
    libmagickwand-dev \
    libjemalloc-dev \
    autoconf \
    bison \
    && rm -rf /var/lib/apt/lists/*

# Install rbenv for Ruby version management
# Using rbenv allows users to install and switch between Ruby versions
RUN git clone https://github.com/rbenv/rbenv.git ~/.rbenv && \
    cd ~/.rbenv && src/configure && make -C src && \
    git clone https://github.com/rbenv/ruby-build.git ~/.rbenv/plugins/ruby-build

# Set rbenv environment variables
ENV PATH="/root/.rbenv/bin:/root/.rbenv/shims:${PATH}"
ENV RBENV_ROOT="/root/.rbenv"

# Initialize rbenv in this shell
RUN echo 'eval "$(rbenv init - bash)"' >> /etc/bash.bashrc

# Install Ruby 3.3 (latest stable) and common gems
# Combine installation to ensure rbenv is properly initialized
RUN echo 'eval "$(rbenv init - bash)"' > /tmp/rbenv-init.sh && \
    bash /tmp/rbenv-init.sh && \
    rbenv install 3.3.6 && \
    rbenv global 3.3.6 && \
    ruby --version && \
    gem update --system && \
    gem install bundler rake rspec rubocop rake-yard rails minitest

# Set environment variables for Ruby development
ENV RUBY_VERSION=3.3.6 \
    RUBYOPT="-Ku -E utf-8" \
    BUNDLE_PATH=/usr/local/bundle \
    BUNDLE_WITHOUT=test \
    BUNDLE_JOBS=4

# Create bundle directory
RUN mkdir -p /usr/local/bundle && chown -R runner:runner /usr/local/bundle

# Add rbenv to runner user's path
RUN echo 'export PATH="/root/.rbenv/bin:/root/.rbenv/shims:$PATH"' >> /home/runner/.bashrc && \
    echo 'eval "$(rbenv init - bash)"' >> /home/runner/.bashrc

# Verify installations as root
RUN eval "$(rbenv init - bash)" && \
    rbenv global 3.3.6 && \
    ruby --version && \
    gem --version && \
    bundle --version

# Labels
LABEL org.opencontainers.image.description="Ruby 3.3 toolchain (rbenv) for GitHub Actions runners" \
      org.opencontainers.image.version="1.0.0" \
      org.opencontainers.image.ruby.version="3.3.6" \
      org.opencontainers.image.ruby.manager="rbenv" \
      org.opencontainers.image.size="~150MB"

USER runner
WORKDIR /actions-runner
