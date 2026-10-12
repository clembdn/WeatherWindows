#!/usr/bin/env bash
# Copies the GitLab repository (the real Xcode project) into this GitHub repository, so CI can build and
# test the same sources: app files → AppStaging/, package → WeatherWindowKit/. Run after each Mac session.
# Usage: Tools/sync-from-gitlab.sh [path to the GitLab clone, default repo-mac-gitlab]
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
gitlab="${1:-$repo_root/repo-mac-gitlab}"

copy() {
    rsync -a --delete --chmod=D755,F644 --exclude .build --exclude .build-docker --exclude .swiftpm "$@"
}

copy --exclude Assets.xcassets "$gitlab/WeatherWindow/" "$repo_root/AppStaging/WeatherWindow/"
copy "$gitlab/WeatherWindowTests/" "$repo_root/AppStaging/WeatherWindowTests/"
copy "$gitlab/WeatherWindowUITests/" "$repo_root/AppStaging/WeatherWindowUITests/"
copy "$gitlab/WeatherWindowKit/Sources/" "$repo_root/WeatherWindowKit/Sources/"
copy "$gitlab/WeatherWindowKit/Tests/" "$repo_root/WeatherWindowKit/Tests/"
cp "$gitlab/WeatherWindowKit/Package.swift" "$repo_root/WeatherWindowKit/Package.swift"

git -C "$repo_root" status --short AppStaging WeatherWindowKit
