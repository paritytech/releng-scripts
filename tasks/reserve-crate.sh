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
version="0.0.0"

while true; do
  case "${1:-}" in
    --check-if-exists)
      check_if_exists=true
      shift
    ;;
    "")
      break
    ;;
    *)
      >&2 echo "Unexpected argument $1"
      exit 1
    ;;
  esac
done

if [ "${check_if_exists:-}" ]; then
  cratesio_url="https://crates.io/api/v1/crates/$name"
  curl -sSLf "$cratesio_url"
  case $? in
    22) # 404, crate doesn't exist; it's free and can be reserved
    ;;
    0)
      >&2 echo "Crate already exists: $1"
      exit 1
    ;;
    *)
      echo "Unexpected request status code: $?"
      exit 1
    ;;
  esac
fi

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
  --define "version=$version" \
  --name "$name"

>/dev/null pushd "$tmp/$name"

find -D exec . -type f -print -exec cat {} \;

cargo publish --token "$token" --allow-dirty

cargo yank --token "$token" --version "$version"
