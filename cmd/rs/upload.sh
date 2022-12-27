#!/usr/bin/env bash

set -Eeu -o pipefail
shopt -s inherit_errexit

this_file="${BASH_SOURCE[0]}"
subcmds_dir="${this_file%/*}"
cmd_dir="${subcmds_dir%/*}"
project_root="${cmd_dir%/*}"
this_filename="${this_file:$(( ${#subcmds_dir} + 1 ))}"
this_subcommand="${this_filename%.*}"
run="${subcmds_dir:$(( ${#cmd_dir} + 1 ))} $this_subcommand"

# shellcheck source=../../lib.sh
. "$project_root/lib.sh"

# shellcheck source=./lib.sh
. "$subcmds_dir/lib.sh"

on_exit() {
  local exit_code=$?

  if [ "${TMP_DOWNLOAD_DIR:-}" ]; then
    rm -rf "$TMP_DOWNLOAD_DIR"
  fi

  print_fallback_to_help "$exit_code"

  exit $exit_code
}
trap on_exit EXIT

# Functions for uploading files to the target backends.
# Those functions receive arguments in a predefined order.

upload_to_s3() {
  local file="$1"
  local bucket="$2"
  local bucket_key="$3"

  local destination="s3://$bucket/$bucket_key"
  local cmd=(
    aws s3 cp
    "${general_backend_args[@]}"
    "${backend_upload_args[@]}"
    "${forwarded_backend_args[@]}"
    --
    "$file"
    "$destination"
  )

  if [ "${DRY_RUN:-}" ]; then
    log "${cmd[*]}"
    return 0
  fi

  # This strategy does not GUARANTEE that files won't be overwritten in all
  # cases. It's provided as a "best effort" feature which should be good enough
  # to prevent obvious mistakes, for instance if you're unintentionally trying
  # to to upload artifacts for a past release because the version is set up
  # incorrectly.
  # Since an exclusive write lock is not acquired during the upload, a race
  # condition can occur where two agents targetting the same path will access
  # the given path *simultaneously* and, in case the file doesn't exist, both
  # will get through this point and both write to the same location
  # simultaneously. Even if the file already exists, it's also possible for
  # multiple agents using "--overwrite" to write to the location at the same
  # time. For more context see:
  # https://github.com/paritytech/release-engineering/pull/113#issuecomment-1297115697
  if [ "${OVERWRITE:-}" ]; then
    log info "File will be overwritten in $destination"
  else
    local response
    response="$(2>&1 aws s3api head-object \
      --output json \
      --bucket "$bucket" \
      --key "$bucket_key" \
      "${general_backend_args[@]:-}"
    )"
    case "$response" in
      *"Not Found")
        # The file doesn't exist, so it can't be overwritten
      ;;
      *)
        log info "Checking metadata for destination $destination"
        if echo -n "$response" | jq -e; then
          # Valid JSON response for metadata, which means that the file exists
          log error "File already exists: $destination"
          log +error "Use \`$run --overwrite ...\` to overwrite it"
        else
          log error "Object metadata response could not be parsed as JSON"
          log +error "Response: $response"
        fi
        return 1
      ;;
    esac
  fi

  "${cmd[@]}"
}

# Usage guidance

print_help() {
  echo "
Usage: $run [OPTIONS] \\
  OPERATION [OPERATION_ARGS] \\
  BACKEND [BACKEND_ARGS] [- [BACKEND_CLI_ARGS] --] \\
  LOCATION...


[OPTIONS]

  * --bucket
    The bucket which the files will be uploaded to. If not specified it's
    inferred from environment variables depending on the backend.

  * --dry
    Process the arguments but don't actually upload the files, i.e. a test run

  * --overwrite
    Use it to disable the check before overwriting a file

  * --help
    Print this help

  * --visibility {public|private}
    Set the visibility for the file to be uploaded. Defaults to public if not
    specified.


$(print_shared_options_usage "$run" "uploaded to")


LOCATION...

  The file paths or URLs to be uploaded to the target bucket.

  If the argument is a URL, it'll be downloaded locally and then uploaded.
"
}

# Script entrypoint

main() {
  # shellcheck disable=SC2034 # FALLBACK_TO_HELP is used in ../rs
  FALLBACK_TO_HELP="$run --help"

  get_opt consume-optional-bool help "$@"
  if [ "${__get_opt_value:-}" ]; then
    print_help
    exit
  fi

  local bucket
  get_opt consume-optional bucket "$@"
  if [ "${__get_opt_value:-}" ]; then
    bucket="$__get_opt_value"
    set -- "${__get_opt_args[@]}"
  fi

  local visibility
  get_opt consume-optional visibility "$@"
  if [ "${__get_opt_value:-}" ]; then
    visibility="$__get_opt_value"
    set -- "${__get_opt_args[@]}"
  else
    visibility=public
  fi

  unset OVERWRITE
  get_opt consume-optional-bool overwrite "$@"
  if [ "${__get_opt_value:-}" ]; then
    set -- "${__get_opt_args[@]}"
    OVERWRITE=true
  fi

  unset DRY_RUN
  get_opt consume-optional-bool dry "$@"
  if [ "${__get_opt_value:-}" ]; then
    set -- "${__get_opt_args[@]}"
    DRY_RUN=true
  fi

  handle_operation "$@"
  set -- "${__handle_operation[@]}"

  handle_backend_options "$this_subcommand" "$visibility" "$@"
  set -- "${__handle_backend_options[@]}"

  unset FALLBACK_TO_HELP

  local exit_code

  # Upload all the input locations

  for location in "$@"; do
    local filename
    filename="$(basename "$location")"

    case "$location" in
      http://*|https://*|ftp://*)
        if [ ! "${TMP_DOWNLOAD_DIR:-}" ]; then
          TMP_DOWNLOAD_DIR="$(mktemp -d)"
        fi
        file="$TMP_DOWNLOAD_DIR/$filename"
        if [ "${DRY_RUN:-}" ]; then
          log default "Faking download from $location to $file"
          touch "$file"
        else
          log default "Downloading $location to $file"
          # notify-send go go
          # sleep 100
          curl -sSL -o "$file" -- "$location"
        fi
      ;;
      *)
        file="$location"
      ;;
    esac

    local remote_destination="$upload_dir/$filename"

    if [ ! "${DRY_RUN:-}" ]; then
      log "Uploading file: $file"
      log "Upload destination: $remote_destination"
    fi

    if "$upload_fn" "$file" "$bucket" "$remote_destination"; then
      log "Upload exit code: $?"
    else
      if [ "${exit_code:-0}" -eq 0 ]; then
        exit_code=1
      else
        exit_code=$?
      fi
      log error "Upload command failed for file: $file"
      log +error "Exit code: $exit_code"
    fi
  done

  exit "${exit_code:-0}"
}

main "$@"
