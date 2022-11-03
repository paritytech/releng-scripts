#!/usr/bin/env bash

set -Eeu -o pipefail
shopt -s inherit_errexit

tasks_dir="${BASH_SOURCE[0]%/*}"
project_root="${tasks_dir%/*}"
tests_dir="$project_root/tests"

# shellcheck source=../lib.sh
. "$project_root/lib.sh"

# shellcheck source=../tests/vars.bash
. "$tests_dir/vars.bash"

cleanup_tests() {
  rm -rf \
    "${AWS_DESTINATIONS_DIR:-}" \
    "${SNAPSHOTS_OVERWRITE_FILE:-}"
  if [ -e "${TESTS_CLEANUP_SESSIONS_FILE:-}" ]; then
    while IFS= read -r session; do
      if [ ! "$session" ]; then
        continue
      fi
      local kill_output
      kill_output="$(2>&1 tmux kill-session -t "$session" || :)"
      case "$kill_output" in
        "can't find session":*) ;;
        *)
          log error "Failed to kill session $session"
          log +error "$kill_output"
        ;;
      esac
    done < "$TESTS_CLEANUP_SESSIONS_FILE"
    rm -f "$TESTS_CLEANUP_SESSIONS_FILE"
  fi
}

on_exit() {
  local exit_code=$?
  cleanup_tests
  exit "$exit_code"
}
trap on_exit EXIT

cleanup_tests

while [ $# -gt 0 ]; do
  case "$1" in
    --update)
      update_snapshots=true
      shift
    ;;
    --check-stale-snapshots)
      check_stale_snapshots=true
      shift
    ;;
    --delete-stale-snapshots)
      check_stale_snapshots=true
      delete_stale_snapshots=true
      shift
    ;;
    --)
      break
    ;;
    *)
      die "Invalid option: $1"
    ;;
  esac
done

if [ "${update_snapshots:-}" ]; then
  mkdir -p "$SNAPSHOTS_DIR"
  touch "$SNAPSHOTS_OVERWRITE_FILE"
fi

if [ "${check_stale_snapshots:-}" ]; then
  snapshots_and_atime=()
  while IFS= read -r snapshot_filename; do
    snapshot_file="$SNAPSHOTS_DIR/$snapshot_filename"
    snapshots_and_atime+=(
      "$snapshot_file"
      "$(stat -c %X "$snapshot_file")"
    )
  done < <(ls "$SNAPSHOTS_DIR")
fi

mkdir -p "$AWS_DESTINATIONS_DIR"
if bats -j "$(nproc)" "$tests_dir"; then
  if [ "${check_stale_snapshots:-}" ]; then
    unset exit_code
    for ((i=0; i < ${#snapshots_and_atime[*]}; i+=2)); do
      snapshot_file="${snapshots_and_atime[$i]}"
      old_atime="${snapshots_and_atime[$((i+1))]}"
      if [ "$(stat -c %X "$snapshot_file")" == "$old_atime" ]; then
        if [ "${delete_stale_snapshots:-}" ]; then
          log info "Deleting stale snapshot $snapshot_file"
          rm "$snapshot_file"
        else
          log error "Snapshot was not touched: $snapshot_file"
          log +error "Perhaps it belongs to a test which no longer exists"
          exit_code=1
        fi
      fi
    done
    exit "${exit_code:-0}"
  fi
else
  exit_code=$?
  log "In case the commands' output is not matching the snapshots, try the --update flag"
  log "In case some stale snapshots were found, try the --delete-stale-snapshots flag"
  exit $exit_code
fi
