# RUBY_VERSION set by build.sh based on .ruby-version file
ARG RUBY_VERSION
FROM public.ecr.aws/docker/library/ruby:${RUBY_VERSION}-alpine

# DataDog logs source
LABEL com.datadoghq.ad.logs='[{"source": "ruby"}]'

# Create web application user to run as non-root
RUN addgroup -g 1000 webapp \
    && adduser -u 1000 -G webapp -s /bin/sh -D webapp \
    && mkdir -p /home/webapp/app
WORKDIR /home/webapp/app

# Upgrade alpine packages (useful for security fixes)
RUN apk upgrade --no-cache

# Install rails/app dependencies
RUN apk --no-cache add libc6-compat git postgresql-libs tzdata mariadb-connector-c yarn

# Copy dependency definitions and lock files
COPY Gemfile Gemfile.lock .ruby-version ./

# Install bundler version which created the lock file and configure it
ARG SIDEKIQ_CREDS
RUN gem install bundler -v $(awk '/^BUNDLED WITH/ { getline; print $1; exit }' Gemfile.lock) \
    && bundle config --global gems.contribsys.com $SIDEKIQ_CREDS

# Install build-dependencies, then install gems, subsequently removing build-dependencies.
# Then drop what installed gems ship for their own development and this app doesn't use:
# the gem cache, git-gem .git folders, top-level spec/test/example folders, and every
# Gemfile.lock inside an installed gem (including brakeman's vendored gems and Ruby's bundled
# rbs). Image scanners read those lock files as installed packages; bundler-audit's spec
# folder alone ships deliberately vulnerable ones. --deployment installs gems under
# vendor/bundle/ruby/<version>/, so the cleanup runs there and never reaches the app's own
# Gemfile.lock. The mkdir keeps find from failing if the app ever stops using git-sourced gems.
RUN apk --no-cache add --virtual build-deps build-base postgresql-dev mariadb-dev yaml-dev \
    && bundle install --deployment --jobs 20 --retry 2 \
    && apk del build-deps \
    && cd /home/webapp/app/vendor/bundle/ruby/*/ \
    && mkdir -p bundler/gems \
    && rm -rf cache bundler/gems/*/.git \
    && find gems bundler/gems -mindepth 2 -maxdepth 2 -type d \
         \( -name spec -o -name test -o -name tests -o -name example -o -name examples \) -exec rm -rf {} + \
    && find gems bundler/gems /usr/local/lib/ruby/gems -type f -name Gemfile.lock -exec rm -f {} +

# Copy the application
COPY . .

# Environment required to build the application
ARG RAILS_ENV=production
ARG BUNDLE_DEPLOYMENT="1"
ARG SECRET_KEY_BASE="abc123"

# Compile assets
# Precompile bootsnap code in the same RUN as the chown; in an earlier layer
# the chown would store a second copy of the cache.
RUN bundle exec bootsnap precompile --gemfile app/ lib/ \
    && SECRET_KEY_BASE_DUMMY=1 RAILS_ENV=production SECRET_KEY_BASE=abc123 bundle exec rake assets:clobber assets:precompile \
    && chown -R webapp:webapp /home/webapp/

# Define volumes used by ECS to share public html and extra nginx config with nginx container
# VOLUME /home/webapp/app/public
# VOLUME /home/webapp/app/nginx-conf

# Run container process as non-root user
USER webapp

# Start server via Thruster by default, this can be overwritten at runtime
EXPOSE 80
CMD ["./bin/thrust", "./bin/rails", "server"]

# Command to start rails
# CMD ["bundle", "exec", "puma", "-C", "config/puma.rb"]
