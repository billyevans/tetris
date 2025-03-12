#!/bin/bash

set -e

ARCH=${1:-x86_64}

docker build --platform=linux/$ARCH --build-arg ARCH=$ARCH -t tetris-test-env -f Dockerfile .

docker run -it --rm \
  -v "$(pwd):/app" \
  tetris-test-env \
  bash -c "cd /app && zig build test"

# docker run -it --rm -v "$(pwd):/app" tetris-test-env
