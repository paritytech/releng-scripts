#!/usr/bin/env bash

## This is a script for dealing with cloud storage platforms such as AWS S3. It
## generates the appropriate arguments for a given backend's API based on its
## input arguments.
## It offers the following benefits over using the backends' APIs directly:
## * It provides a common interface for different backend APIs.
## * It automatically sets the right path for a given file based on the
##   OPERATION so that users don't have to remember path conventions
##   manually.
## * Its API is more resilient to breaking changes since arguments can be
##   adapted over time according to our needs.
## Try --help for guidance on how to use it.

set -Eeu -o pipefail
shopt -s inherit_errexit

this_file="${BASH_SOURCE[0]}"
project_root="${this_file%/*}"
# shellcheck source=./lib.sh
. "$project_root/lib.sh"
this_filename="${this_file:$(( ${#project_root} + 1 ))}"

on_exit() {
  local exit_code=$?

  print_fallback_to_help "$exit_code"

  exit $exit_code
}
trap on_exit EXIT

# Usage guidance

print_help() {
echo "
Usage: $this_filename [--help] SUBCOMMAND [SUBCOMMAND_ARGS]


SUBCOMMANDS

  * upload
    Uploads the files to some remote storage.
    Use \`$this_filename upload --help\` for usage guidance.

  * delete
    Deletes files from some remote storage.
    Use \`$this_filename delete --help\` for usage guidance.
"
}

# Script entrypoint

main() {
  FALLBACK_TO_HELP="$this_filename --help"

  get_opt consume-optional-bool help "$@"
  if [ "${__get_opt_value:-}" ]; then
    print_help
    exit
  fi

  unset FALLBACK_TO_HELP

  local subcommand="$1"; shift
  case "$subcommand" in
    upload|delete|download)
      "$project_root/cmd/$this_filename/$subcommand.sh" "$@"
    ;;
    *)
      die "Invalid subcommand: $subcommand"
    ;;
  esac
}

if [ "$#" -eq 0 ]; then
  print_help
else
  main "$@"
fi
