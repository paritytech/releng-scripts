#!/usr/bin/env bash

# shellcheck disable=SC2034
# SC2034: Exported variables are used externally by other scripts

handle_operation() {
  operation="$1"; shift

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

  __handle_operation=("$@")
}

handle_backend_options() {
  local command="$1"; shift
  local visibility="$1"; shift

  backend="$1"; shift
  case "$command" in
    upload)
      upload_fn="upload_to_$backend"
    ;;
    delete)
      delete_fn="delete_from_$backend"
    ;;
    download)
      download_fn="download_from_$backend"
    ;;
    *)
      die "Invalid subcommand: $command"
    ;;
  esac

  general_backend_args=() # options which apply to the whole backend's CLI
  backend_upload_args=()  # options which apply only to the upload command

  if [ "$visibility" ]; then
    case "$backend" in
      s3)
        case "$command" in
          upload)
            case "$visibility" in
              public)
                backend_upload_args+=(--acl public-read)
              ;;
              private)
                backend_upload_args+=(--acl private)
              ;;
              *)
                die "Invalid visibility: $visibility"
              ;;
            esac
          ;;
          *)
            die "Visibility is not is handled for command: $command"
          ;;
        esac
      ;;
      *)
        die "Visibility is not is handled for backend: $backend"
      ;;
    esac
  fi

  case "$backend" in
    s3)
      if [ ! "${bucket:-}" ]; then
        if [ "${AWS_BUCKET:-}" ]; then
          bucket="$AWS_BUCKET"
        else
          die "Could not infer the target bucket from --bucket nor \$AWS_BUCKET"
        fi
      fi

      get_opt consume-optional-bool s3mock "$@"
      if [ "${__get_opt_value:-}" ]; then
        # shellcheck disable=SC2154 # __get_opt_args is exported from get_opt
        set -- "${__get_opt_args[@]}"

        # Disables urllib warnings for self-signed HTTPS certificates when
        # targetting a local S3 mock service such as https://github.com/adobe/S3Mock
        export PYTHONWARNINGS="ignore:Unverified HTTPS request"

        general_backend_args+=(
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

  forwarded_backend_args=()  # options which are forwarded to the backend's CLI
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
          forwarded_backend_args+=("$1")
          shift
        ;;
      esac
    done
  fi

  __handle_backend_options=("$@")
}

print_shared_options_usage() {
  local run="$1"
  local action="$2"

  echo "OPERATIONS

  * release REPOSITORY VERSION

    Used to upload the GitHub Release artifacts for a given REPOSITORY.

  * gha

    This operation is meant to be used from inside of GitHub Workflows. It does
    not require arguments because it leverages the environment variables present
    in GitHub Workflows.

  * custom DIRECTORY

    Accepts one positional argument, [DIRECTORY], which is the directory where
    the file will be uploaded to. For example:

    $run --bucket test \\
      custom my/custom/path \\
      s3 \\
      foo.txt

    That will make the file be $action s3://test/my/custom/path/foo.txt.

    Note: DIRECTORY cannot start or end with '/', as that's the delimiter used
    for concatenating the whole file destination.


BACKENDS

  * s3 [--s3mock]

    Targets AWS S3.

    --s3mock can be optionally provided for setting up the use for targetting a
    local instance https://github.com/adobe/S3Mock. Consult the README for how
    to set up a S3Mock local server.


[BACKEND_CLI_ARGS]

  [BACKEND_CLI_ARGS] defines CLI arguments to be forwarded to the CLI tool
  assigned to a given BACKEND. The arguments MUST start with \"-\" and MUST be
  terminated with \"--\". For example:

    $run --bucket test \\
      custom custom/path \\
      s3 - --acl write -- \\
      foo.txt

    That will append the \"--acl\" and \"write\" arguments to the S3 CLI's
    default arguments.
"
}
