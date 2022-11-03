#!/usr/bin/env bash

log() {
  if [ "${2:-}" ]; then
    local target="$1"
    local msg="$2"
  else
    local target="default"
    local msg="$1"
  fi
  case "$target" in
    error)
      >&2 echo "[ERROR] $msg"
    ;;
    +error)
      if [ "${__log_last_target:-}" == "error" ]; then
        >&2 echo "        $msg"
      else
        >&2 echo "[ERROR] $msg"
      fi
    ;;
    info)
      echo "[INFO] $msg"
    ;;
    default)
      echo "$msg"
    ;;
    *)
      die "Invalid logging target: $target"
    ;;
  esac
  __log_last_target="$target"
}

die() {
  if [ "${1:-}" ]; then
    log error "$1"
  fi
  exit 1
}

splice() {
  local splice_count="$1"; shift
  local splice_idx="$1"; shift
  local args=("$@")

  local exclude_start="$splice_idx"
  local exclude_end="$(( splice_idx + splice_count ))"

  __splice=()
  for ((i=0; i < ${#args[*]}; i++)); do
    if [[ "$i" -lt "$exclude_start" || "$i" -gt "$exclude_end" ]]; then
      __splice+=("${args[$i]}")
    fi
  done
}

get_opt() {
  local operation="$1"; shift
  local opt_name="$1"; shift

  unset __get_opt_args __get_opt_value

  local is_consuming_arg is_flag is_required
  case "$operation" in
    consume-optional-bool)
      is_flag=true
      is_consuming_arg=true
    ;;
    consume-optional)
      is_consuming_arg=true
    ;;
    consume)
      is_consuming_arg=true
      is_required=true
    ;;
    *)
      die "Expected [consume-optional | consume-required], got: $operation"
    ;;
  esac

  local opt_value
  local args=("$@")
  for ((i=0; i < ${#args[*]}; i++)); do
    local opt_arg="--$opt_name"
    case "${args[$i]}" in
      "$opt_arg="*) # --foo=bar
        opt_value="${args[$i]:$(( ${#opt_arg} + 1 ))}"
        if [ "${is_consuming_arg:-}" ]; then
          splice 0 "$i" "${args[@]}"
          args=("${__splice[@]}")
        fi
        break
      ;;
      "$opt_arg") # "--foo bar" OR "--foo"
        if [ "${is_flag:-}" ]; then
          opt_value=true
        else
          opt_value="${args[$(( i + 1 ))]}"
        fi
        if [ "${is_consuming_arg:-}" ]; then
          if [ "${is_flag:-}" ]; then
            splice 0 "$i" "${args[@]}"
          else
            splice 1 "$i" "${args[@]}"
          fi
          args=("${__splice[@]}")
        fi
        break
      ;;
      --*=*)
        # Option of the form --foo=bar, but not the one we're looking for
      ;;
      --*)
        # Option of the form --foo bar, but not the one we're looking for
        case "${args[$(( i + 1 ))]:-}" in
          --|--*)
            # Next argument is another option; it can't be skipped over,
            # otherwise we might miss the option we're searching for.
          ;;
          *)
            # Next argument is NOT an option, it's the value for the current
            # option.
            ((i += 1))
          ;;
        esac
      ;;
      *)
        # Current argument is not an option; stop parsing
        break
      ;;
    esac
  done

  # shellcheck disable=SC2034 # variable is used externally
  __get_opt_args=("${args[@]}")

  if [ "${opt_value:-}" ]; then
    # shellcheck disable=SC2034 # variable is used externally
    __get_opt_value="$opt_value"
  elif [ "${is_required:-}" ]; then
    die "Required option was empty: $opt_name"
  fi
}

trim_val() {
  local val="$1"; shift
  for char in "$@"; do
    while [ "${val::1}" == "$char" ]; do
      val="${val:1}"
    done
    while [ "${val: -1}" == "$char" ]; do
      val="${val:: -1}"
    done
  done
  echo "$val"
}

trim() {
  trim_val "$1" $'\n' ' '
}
