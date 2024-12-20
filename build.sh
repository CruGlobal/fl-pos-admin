#!/bin/bash

docker buildx build $DOCKER_ARGS \
    --build-arg RAILS_ENV=$ENVIRONMENT \
    --build-arg SIDEKIQ_CREDS=$SIDEKIQ_CREDS \
    --build-arg RUBY_VERSION=$(cat .ruby-version) \
    --build-arg SECRET_KEY_BASE=$SECRET_KEY_BASE \
    .
rc=$?

if [ $rc -ne 0 ]; then
  echo -e "Docker build failed"
  exit $rc
fi
