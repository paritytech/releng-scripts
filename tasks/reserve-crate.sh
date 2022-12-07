#!/usr/bin/env bash

set -Eeu -o pipefail
shopt -s inherit_errexit

set -x

author="$CRATE_AUTHOR"
name="$CRATE_NAME"
description="$CRATE_DESCRIPTION"
repository_url="$CRATE_REPOSITORY_URL"
license="$CRATE_LICENSE"
type="$CRATE_TYPE"
token="$CRATESIO_TOKEN"

this_file="$(realpath -s "${BASH_SOURCE[0]}")"
this_dir="${this_file%/*}"
project_root="${this_dir%/*}"

tmp="$(mktemp -d)"

on_exit() {
  local exit_code=$?
  rm -rf "$tmp"
  exit "$exit_code"
}
trap on_exit EXIT

cargo generate \
  --path "$project_root/template/crates/$type" \
  --vcs none \
  --destination "$tmp" \
  --define "name=$name" \
  --define "author=$author" \
  --define "description=$description" \
  --define "repository_url=$repository_url" \
  --define "license=$license" \
  --name "$name"

>/dev/null pushd "$tmp/$name"

find -D exec . -type f -print -exec cat {} \;

cargo publish --token "$token" --allow-dirty

cargo yank --token "$token" --version 0.0.0
