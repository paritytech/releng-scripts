#!/usr/bin/env bash

# First it replaces literal parts, such as $PROJECT_ROOT, with Python, so it's
# not necessary care about escaping characters for sed's expressions. After that
# it handle non-literal replacements, such as regular expressions, with sed.
sanitize_snapshot_output() {
  python -c '
import sys
output = sys.argv[1]
for i in range(2, len(sys.argv), 2):
  output = output.replace(sys.argv[i], sys.argv[i+1])
sys.stdout.write(output + "\n")
    ' \
    "$output" \
    "$PROJECT_ROOT/" "" \
    | sed -e 's|/tmp/tmp.[^/]*||'
}

# Modifying the access times of snapshot files is useful so that we can detect
# stale snapshots (those which were not accessed during the test suite run)
touch_snapshot() {
  if [ -e "$SNAPSHOT_PATH" ]; then
    touch -a "$SNAPSHOT_PATH"
  fi
}

# Compares the status as well as the output of a given command with the file
# stored in ./snapshots for a given tests. The first line of the snapshot file
# contains the exit code of the command and the remainder of the file stores the
# command's output.
assert_snapshot() {
  local mode="${1:-}"

  case "$mode" in
    status)
      only_keep_status=true
    ;;
    "") ;;
    *)
      log error "Invalid mode: $mode"
      return 1
    ;;
  esac

  mkdir -p "$SNAPSHOTS_DIR"

  local output="$output"
  output="$(trim "$output" | sanitize_snapshot_output "$output")"

  local status="${status:-0}"

  if [ -e "${SNAPSHOTS_OVERWRITE_FILE:-}" ] || [ ! -e "$SNAPSHOT_PATH" ]; then
    local content="$status"
    if [ ! "${only_keep_status:-}" ]; then
      content+=$'\n'"$output"
    fi
    echo "$content" > "$SNAPSHOT_PATH"
    return
  fi

  snapshot_status="$(head -n 1 "$SNAPSHOT_PATH")"
  if [ "$status" != "$snapshot_status" ]; then
    log error "Expected status: $snapshot_status"
    log +error "Got status: $status"
    log +error "Command output: $output"
    return 1
  fi

  snapshot_output="$(tail -n +2 "$SNAPSHOT_PATH")"

  if [ "${only_keep_status:-}" ]; then
    if [ "$snapshot_output" ]; then
      echo "$status" > "$SNAPSHOT_PATH"
    fi
    return 0
  fi

  if [ "$output" != "$snapshot_output" ]; then
    diff -u --color=always <(echo -n "$snapshot_output") <(echo -n "$output")
    log error "Output doesn't match the snapshot at $SNAPSHOT_PATH"
  fi
}
