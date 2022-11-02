#!/usr/bin/env bash

# shellcheck disable=SC2034
# SC2034: The variables are used externally by other scripts

TESTS_DIR="${BASH_SOURCE[0]%/*}"
PROJECT_ROOT="${TESTS_DIR%/*}"
SNAPSHOTS_DIR="$TESTS_DIR/__snapshot__"

# Those files should be ignored in .gitignore
SNAPSHOTS_OVERWRITE_FILE="$TESTS_DIR/.snapshots-overwrite"
TESTS_CLEANUP_SESSIONS_FILE="$TESTS_DIR/.cleanup-pids"
AWS_DESTINATIONS_DIR="$TESTS_DIR/.aws-destinations"

# The following variables are only available during tests
if [ "${BATS_TEST_FILENAME:-}" ]; then
  TEST_FILENAME_DIR="${BATS_TEST_FILENAME%/*}"
  TEST_FILENAME="${BATS_TEST_FILENAME:$((${#TEST_FILENAME_DIR}+1))}"
  SNAPSHOT_PATH="$SNAPSHOTS_DIR/${TEST_FILENAME%.*}-$BATS_TEST_NAME.snap"
fi
