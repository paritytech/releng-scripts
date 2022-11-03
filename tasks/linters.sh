#!/usr/bin/env bash

set -Eeu -o pipefail
shopt -s inherit_errexit

tasks_dir="${BASH_SOURCE[0]%/*}"
project_root="${tasks_dir%/*}"

# shellcheck source=../lib.sh
. "$project_root/lib.sh"

git ls-files --full-name | \
  while IFS= read -r file_line; do
    file="$project_root/$file_line"
    if [ ! -e "$file" ]; then
      continue
    fi
    case "$file" in
      *.sh|*.bash)
        echo "$file"
      ;;
      *)
        file_shebang="$(head -n 1 "$file")"
        case "$file_shebang" in
          "#!/usr/bin/env bash")
            echo "$file"
          ;;
          "#!"*)
            die "Shebang of $file was unexpected: $file_shebang"
          ;;
        esac
      ;;
    esac
  done | \
  xargs -P "$(nproc)" -L 1 shellcheck -x --source-path=SCRIPTDIR
