#!/usr/bin/env bash
# Copies the GitLab repository (the real Xcode project) into WeatherWindow/, so GitHub CI builds and tests
# exactly the project shown at the interview. Run after each change in the GitLab clone.
# Usage: Tools/sync-from-gitlab.sh [path to the GitLab clone, default repo-mac-gitlab]
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
gitlab="${1:-$repo_root/repo-mac-gitlab}"

rsync -a --delete --chmod=D755,F644 \
    --exclude .git --exclude xcuserdata --exclude .build --exclude .build-docker --exclude .swiftpm \
    "$gitlab/" "$repo_root/WeatherWindow/"

git -C "$repo_root" status --short WeatherWindow
