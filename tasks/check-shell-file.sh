#!/usr/bin/env bash

set -Eeu -o pipefail
shopt -s inherit_errexit

for file in "$@"; do
  case "$file" in
    *.sh|*.bash) ;;
    *)
      file_shebang="$(head -n 1 "$file")"
      case "$file_shebang" in
        "#!/usr/bin/env bash") ;;
        "#!"*)
          >&2 echo "Shebang of $file was unexpected: $file_shebang"
          exit 1
        ;;
        *)
          continue
        ;;
      esac
    ;;
  esac
  shellcheck -x --source-path=SCRIPTDIR "$file"
done
