#!/usr/bin/env bash

tests_dir="${BASH_SOURCE[0]%/*}"
fixtures_dir="$tests_dir/fixtures"
tests_bin_dir="$tests_dir/bin"

test_output() {
  local subcommand="$1"; shift
  case "$subcommand" in
    append)
      __test_output+=$'\n'"$1"$'\n'
    ;;
    collect)
      # shellcheck disable=SC2034
      # SC2034: the $output variable is produced by BATS' "run" command
      output="$__test_output"
    ;;
    clear)
      unset __test_output
    ;;
  esac
}

wait_for_tmux() {
  local is_tmux_ready
  for ((i=0; i < 10; i++)); do
    local tmux_output
    tmux_output="$(tmux info 2>&1 || :)"
    case "$tmux_output" in
      *"no server"*)
        sleep 1
      ;;
      *)
        is_tmux_ready=true
        break
      ;;
    esac
  done
  if [ ! "${is_tmux_ready:-}" ]; then
    die "TMUX server initialization timed out"
  fi
}

# Sets up an HTTP server so that files can be downloaded from it.
# Used during tests to test the download features of some scripts.
fixtures_server() {
  local subcommand="$1"; shift
  case "$subcommand" in
    start)
      local tmp_test_dir="$1"

      # We set up a pipe for being able to wait until the server is ready
      # without blocking the script's execution.
      __fixtures_server_pipe="$tmp_test_dir/fixtures-server-pipe"
      mkfifo "$__fixtures_server_pipe"

      # Set up the server on a TMUX session so that it can be disposed of
      # predictably.
      # Previous attempts using barebones background shells could not be
      # disposed of cleanly because those shells would be terminated once the
      # test suite finished, but not their children processes. This meant that
      # occasionally processes would be lingering after the test suite had
      # finished. We chose to run it within a TMUX session so that it can always
      # be terminated cleanly, either within the test (with `fixtures_server
      # stop`) or in ../tasks/tests.sh (in the on_exit trap function).

      wait_for_tmux

      __fixtures_server_session="BATS-$$-$BATS_TEST_NUMBER-FIXTURES_SERVER"
      tmux new-session \
        -s "$__fixtures_server_session" \
        -d "$tests_bin_dir/fixtures-server" \
          "$__fixtures_server_pipe" \
          "$fixtures_dir"
      echo "$__fixtures_server_session" >> "$TESTS_CLEANUP_SESSIONS_FILE"

      timeout 8 "$tests_bin_dir/wait-for-fixtures-server" "$__fixtures_server_pipe"
    ;;
    kill)
      tmux kill-session -t "$__fixtures_server_session"
    ;;
  esac
}
