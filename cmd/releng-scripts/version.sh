#!/usr/bin/env bash

this_file="${BASH_SOURCE[0]}"
subcmds_dir="${this_file%/*}"
cmd_dir="${subcmds_dir%/*}"
project_root="${cmd_dir%/*}"

cat "$project_root/VERSION"
