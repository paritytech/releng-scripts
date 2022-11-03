#!/usr/bin/env bash

set -Eeu -o pipefail
shopt -s inherit_errexit

this_file="${BASH_SOURCE[0]}"
subcmds_dir="${this_file%/*}"
cmd_dir="${subcmds_dir%/*}"
project_root="${cmd_dir%/*}"
this_filename="${this_file:$(( ${#subcmds_dir} + 1 ))}"
run="${subcmds_dir:$(( ${#cmd_dir} + 1 ))} ${this_filename%.*}"

# shellcheck source=../../lib.sh
. "$project_root/lib.sh"

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

upload_s3() {
  local file="$1"; shift
  local bucket="$1"; shift
  local bucket_key="$1"; shift
  local backend_options=("$@")

  local destination="s3://$bucket/$bucket_key"
  local cmd=(aws s3 cp "${backend_options[@]}" -- "$file" "$destination")

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
      "${backend_options[@]}"
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
          log +error "Use \`$run --overwrite [...]\` to overwrite it"
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

print_help() {
  echo "
Usage: $run [OPTIONS...] \\
  OPERATION [OPERATION_ARGS...] \\
  BACKEND [BACKEND_ARGS...] [- [BACKEND_CLI_ARGS...] --] \\
  [LOCATION...]


[OPTIONS...]

  * --bucket
    The bucket which the files will be uploaded to. The bucket can also be
    inferred from environment variables depending on the backend.

  * --dry
    Process the arguments but don't actually upload the files, i.e. a test run

  * --overwrite
    Use it to disable the check before overwriting a file

  * --debug
    Enable debug mode; useful for testing the tool locally

  * --help
    Print this help


OPERATIONS

  * release REPOSITORY VERSION

    Used to upload the GitHub Release artifacts for a given REPOSITORY.

  * gha

    This operation is meant to be used from inside of GitHub Workflows. It does
    not require arguments because it leverages the environment variables present
    in GitHub Workflows.

  * custom DIRECTORY

    Accepts one positional argument, [DIRECTORY], which is the directory where
    the file will be uploaded to. For example:

    $this_filename --bucket test \\
      custom my/custom/path \\
      s3 \\
      foo.txt

    That will make the file be uploaded to s3://test/my/custom/path/foo.txt.

    Note: DIRECTORY cannot start or end with '/', as that's the delimiter used
    for concatenating the final file destination.

BACKENDS

  * s3 [--s3mock]

    Targets AWS S3.

    --s3mock can be optionally provided for setting up the use for targetting a
    local instance https://github.com/adobe/S3Mock. Consult the README for how
    to set up a S3Mock local server.


[BACKEND_CLI_ARGS...]

  [BACKEND_CLI_ARGS...] defines CLI arguments to be forwarded to the CLI tool
  assigned to a given BACKEND. The arguments MUST start with \"-\" and MUST be
  terminated with \"--\". For example:

    $this_filename --bucket test \\
      custom custom/path \\
      s3 - --acl write -- \\
      foo.txt

    That will append the \"--acl\" and \"write\" arguments to the S3 CLI's
    default arguments.


[LOCATION...]

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

  # Handle the operation

  local upload_dir
  local operation="$1"; shift
  case "$operation" in
    release)
      local repository="$1"; shift
      local version="$1"; shift
      upload_dir="$repository/$version"
    ;;
    gha)
      upload_dir="$GITHUB_REPOSITORY_OWNER/gh-workflow/$GITHUB_WORKFLOW/$GITHUB_RUN_ID"
    ;;
    custom)
      upload_dir="$1"; shift
      if [ "${upload_dir:: 1}" == '/' ]; then
        die "Custom upload directory can't start with '/': $upload_dir"
      fi
      if [ "${upload_dir: -1}" == '/' ]; then
        die "Custom upload directory can't end with '/': $upload_dir"
      fi
    ;;
    *)
      die "Invalid operation: $operation"
    ;;
  esac

  # Handle the backend

  local backend_options=()

  local backend="$1"; shift
  case "$backend" in
    s3)
      upload_fn=upload_s3

      if [ ! "${bucket:-}" ]; then
        if [ "${AWS_BUCKET:-}" ]; then
          bucket="$AWS_BUCKET"
        else
          die "Could not infer the target bucket from --bucket or \$AWS_BUCKET"
        fi
      fi

      get_opt consume-optional-bool s3mock "$@"
      if [ "${__get_opt_value:-}" ]; then
        set -- "${__get_opt_args[@]}"

        # Disables urllib warnings for self-signed HTTPS certificates when
        # targetting a local S3 mock service such as https://github.com/adobe/S3Mock
        export PYTHONWARNINGS="ignore:Unverified HTTPS request"

        backend_options+=(
          "--endpoint-url=https://localhost:9191"
          "--no-verify-ssl"
        )
      fi
    ;;
    *)
      die "Invalid backend: $backend"
    ;;
  esac

  # Collect options to be forwarded to the backend's CLI

  if [ "$1" == '-' ]; then
    # "-" starts the chain of arguments to be passed to the backend
    shift
    while [ $# -gt 0 ]; do
      case "$1" in
        --) # "--" finishes the chain of arguments to be passed to the backend
          shift
          break
        ;;
        *)
          backend_options+=("$1")
          shift
        ;;
      esac
    done
  fi

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

    local upload_destination="$upload_dir/$filename"

    if [ ! "${DRY_RUN:-}" ]; then
      log "Uploading file: $file"
      log "Upload destination: $upload_destination"
    fi

    if "$upload_fn" \
      "$file" "$bucket" "$upload_destination" \
      "${backend_options[@]}"
    then
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
