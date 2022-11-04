#!/usr/bin/env bash

set -Eeu -o pipefail
shopt -s inherit_errexit

tasks_dir="${BASH_SOURCE[0]%/*}"

parallel=(xargs -r -P "$(nproc)" -L 1)

if [ "${FILES_FROM_GIT_ROOT:-}" ]; then
  export GIT_ROOT="$FILES_FROM_GIT_ROOT"
  readarray -t files < <(
    git ls-files --full-name | "${parallel[@]}" "$tasks_dir/filter-shell-file.sh"
  )
else
  export GIT_ROOT="$PWD"
  readarray -t files < <(
    printf '%s\n' "$@" | "${parallel[@]}" "$tasks_dir/filter-shell-file.sh"
  )
fi

if [ ${#files[*]} -eq 0 ]; then
  exit
fi

# for some reason shellcheck misbehaves if its CWD is the repository
# thus we first change our CWD to the .git folder
>/dev/null pushd "$GIT_ROOT/.git"

printf '%s\n' "${files[@]}" | "${parallel[@]}" shellcheck -x --source-path=SCRIPTDIR
