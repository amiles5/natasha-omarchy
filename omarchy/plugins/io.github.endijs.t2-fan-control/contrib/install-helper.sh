#!/usr/bin/env bash

set -euo pipefail

here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
helper=/usr/local/libexec/omarchy-t2-fan-control
policy=/usr/share/polkit-1/actions/io.github.endijs.t2-fan-control.policy

(( EUID == 0 )) || {
  printf 'Run this installer as root: sudo %s\n' "$0" >&2
  exit 1
}

if [[ ${1:-} == --uninstall ]]; then
  [[ $# == 1 ]] || { printf 'Expected only --uninstall\n' >&2; exit 1; }
  rm -f -- "$helper" "$policy"
  printf 'Removed %s and %s\n' "$helper" "$policy"
  exit 0
fi

[[ $# == 0 ]] || { printf 'Unknown argument: %s\n' "$1" >&2; exit 1; }
install -Dm755 -o root -g root "$here/omarchy-t2-fan-control" "$helper"
install -Dm644 -o root -g root "$here/io.github.endijs.t2-fan-control.policy" "$policy"
printf 'Installed %s and %s\n' "$helper" "$policy"
