#!/bin/sh
set -eu

REGISTRY=ccds-project.duckdns.org
VERSION=1.0
cd "$(dirname "$0")"

for svc in core static db smtp backup auto; do
    image="$REGISTRY/app-$svc:$VERSION"
    echo "== $image"
    docker build -t "$image" "$svc"
    docker push "$image"
done
