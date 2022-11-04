#!/usr/bin/env bash

set -Eeu -o pipefail
shopt -s inherit_errexit

for file in "$@"; do
  if [ "${GIT_ROOT:-}" ]; then
    file="$GIT_ROOT/$file"
    if [ ! -e "$file" ]; then
      continue
    fi
  fi
  case "$file" in
    *.sh|*.bash) ;;
    *)
      file_shebang="$(head -n 1 "$file")"
      case "$file_shebang" in
        "#!/usr/bin/env bash") ;;
        "#!"*)
          >&2 echo "[ERROR] Shebang of $file was unexpected: $file_shebang"
          exit 1
        ;;
        *)
          exit
        ;;
      esac
    ;;
  esac

  echo "$file"
done
