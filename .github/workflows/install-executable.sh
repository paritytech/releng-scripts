#!/usr/bin/env bash

set -Eeu -o pipefail
shopt -s inherit_errexit

exe_name="$1"
download_url="$2"
expected_checksum="$3"

download_dir="$(mktemp -d)"

curl -sSL -o "$download_dir/$exe_name" -- "$download_url"
chmod +x "$download_dir/$exe_name"

checksum_output="$(sha256sum "$download_dir/$exe_name")"
expected_checksum_output="$expected_checksum  $download_dir/$exe_name"
if [ "$checksum_output" != "$expected_checksum_output" ]; then
  >&2 echo "[ERROR] Mismatching checksum for $exe_name"
  >&2 echo "Expected: $expected_checksum_output"
  >&2 echo "Got: $checksum_output"
  exit 1
fi

echo "$download_dir"
