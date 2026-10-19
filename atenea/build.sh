#!/bin/sh
# Builds the atenea images and pushes them to the team registry.
# Log in first: docker login ccds-project.duckdns.org
set -eu

REGISTRY=ccds-project.duckdns.org
VERSION=1.0
cd "$(dirname "$0")"

for svc in moodle backup; do
    image="$REGISTRY/atenea-$svc:$VERSION"
    echo "== $image"
    docker build -t "$image" "$svc"
    docker push "$image"
done
