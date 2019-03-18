#!/bin/bash

set -e
echo "$DOCKER_PASSWORD" | docker login -u "$DOCKER_USERNAME" --password-stdin https://index.docker.io/v1;
docker run --rm -i "$DOCKER_USERNAME"/"$DOCKER_REPO":"$TRAVIS_COMMIT" container ./vendor/bin/phpunit