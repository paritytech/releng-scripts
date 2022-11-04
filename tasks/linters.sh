#!/usr/bin/env bash

set -Eeu -o pipefail
shopt -s inherit_errexit

tasks_dir="${BASH_SOURCE[0]%/*}"

FILES_FROM_GIT_ROOT="$(git rev-parse --show-toplevel)" "$tasks_dir/check-shell-file.sh"
