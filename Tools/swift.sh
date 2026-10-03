#!/usr/bin/env bash
# Runs SwiftPM inside the same Swift image as CI, matching the Swift version of Xcode 26.
# Usage: Tools/swift.sh test    (any swift subcommand, run in WeatherWindowKit/)
set -euo pipefail

image="swift:6.3.3-noble"
repo_root="$(cd "$(dirname "$0")/.." && pwd)"

exec docker run --rm \
    --user "$(id -u):$(id -g)" \
    --env HOME=/tmp \
    --volume "$repo_root:/repo" \
    --workdir /repo/WeatherWindowKit \
    "$image" \
    swift "$@" --scratch-path .build-docker
