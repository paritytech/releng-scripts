#!/usr/bin/env bash

set -Eeu -o pipefail
shopt -s inherit_errexit

tests_dir="${BATS_TEST_FILENAME%/*}"
fixtures_dir="$tests_dir/fixtures"
project_root="${tests_dir%/*}"

uploader_base_args=(upload --bucket test)
uploader_dry_args=("${uploader_base_args[@]}" --dry custom test)
uploader_overwrite_args=(
  "${uploader_base_args[@]}"
  --overwrite
  custom test
  s3 "$fixtures_dir/foo.txt"
)
uploader_default_args=(
  "${uploader_base_args[@]}"
  custom test
  s3 "$fixtures_dir/foo.txt"
)

deleter_base_args=(delete --bucket test)
deleter_dry_args=("${deleter_base_args[@]}" --dry custom test)
deleter_default_args=(
  "${deleter_base_args[@]}"
  custom test
  s3 "$fixtures_dir/foo.txt"
)

setup() {
  set -Eeu -o pipefail
  shopt -s inherit_errexit

  load "$project_root/lib.sh"

  load helpers
  load snapshots

  load vars

  OLD_PATH="$PATH"
  export PATH="$tests_dir/mocks:$PATH"

  export AWS_DESTINATION_FILE="$AWS_DESTINATIONS_DIR/$$-$BATS_TEST_NUMBER"
}

teardown() {
  rm -rf "$AWS_DESTINATION_FILE" "${TMP_TEST_DIR:-}"
  PATH="$OLD_PATH"
  unset OLD_PATH
}

@test "help can be printed" {
  touch_snapshot
  run "$project_root/rs" --help
  assert_snapshot status
}

@test "upload help can be printed" {
  touch_snapshot
  run "$project_root/rs" upload --help
  assert_snapshot status
}

@test "delete help can be printed" {
  touch_snapshot
  run "$project_root/rs" delete --help
  assert_snapshot status
}

@test "backend options are properly forwarded for upload" {
  touch_snapshot
  run "$project_root/rs" "${uploader_dry_args[@]}" \
    s3 - --foo --bar -- \
    PLACEHOLDER
  assert_snapshot
}

@test "backend options are properly forwarded for delete" {
  touch_snapshot
  run "$project_root/rs" "${deleter_dry_args[@]}" \
    s3 - --foo --bar -- \
    PLACEHOLDER
  assert_snapshot
}

@test "files can only be overwritten with --overwrite" {
  touch_snapshot

  test_output append "=== UPLOAD THE FILE ==="
  run "$project_root/rs" "${uploader_default_args[@]}"
  test_output append "$output"

  test_output append "=== UPLOAD FAILS BECAUSE OVERWRITE IS DISABLED ==="
  run "$project_root/rs" "${uploader_default_args[@]}"
  test_output append "$output"

  test_output append "=== UPLOAD WORKS BECAUSE OF --overwrite ==="
  run "$project_root/rs" "${uploader_overwrite_args[@]}"
  test_output append "$output"

  test_output collect
  assert_snapshot
}

@test "gha operation works" {
  touch_snapshot
  GITHUB_REPOSITORY_OWNER=polkadot \
  GITHUB_WORKFLOW=foo \
  GITHUB_RUN_ID=123 \
    run "$project_root/rs" "${uploader_base_args[@]}" --dry \
      gha \
      s3 PLACEHOLDER
  assert_snapshot
}

@test "release operation works" {
  touch_snapshot
  run "$project_root/rs" "${uploader_base_args[@]}" --dry \
    release polkadot v0.9.30 \
    s3 PLACEHOLDER
  assert_snapshot
}

@test "custom operation works" {
  touch_snapshot
  run "$project_root/rs" "${uploader_dry_args[@]}" \
    s3 PLACEHOLDER
  assert_snapshot
}

@test "files can be downloaded before upload" {
  touch_snapshot

  TMP_TEST_DIR="$(mktemp -d)"

  fixtures_server start "$TMP_TEST_DIR"

  local upload_args=(
    "${uploader_default_args[@]:: $(( ${#uploader_default_args[*]} - 1 ))}"
    http://0.0.0.0:8000/foo.txt
  )
  run "$project_root/rs" "${upload_args[@]}"

  fixtures_server kill

  assert_snapshot
}

@test "files can be deleted" {
  touch_snapshot
  run "$project_root/rs" "${deleter_default_args[@]}"
  assert_snapshot
}

@test "uploading with --dry works" {
  touch_snapshot
  run "$project_root/rs" "${uploader_dry_args[@]}" s3 "$fixtures_dir/foo.txt"
  assert_snapshot
}

@test "deleting with --dry works" {
  touch_snapshot
  run "$project_root/rs" "${deleter_dry_args[@]}" s3 "$fixtures_dir/foo.txt"
  assert_snapshot
}
