#!/usr/bin/env bash
# Bisect Rust GDExtensions to find which one prevents Brain Visualizer from loading.
# Godot does not load files named *.gdextension.off; use that to disable an extension.
#
# Usage:
#   ./bisect_extensions.sh status          - list extensions and enabled/disabled state
#   ./bisect_extensions.sh disable-all     - disable all Rust GDExtensions
#   ./bisect_extensions.sh enable-all      - enable all Rust GDExtensions
#   ./bisect_extensions.sh disable <N>     - disable extension by index (1-based)
#   ./bisect_extensions.sh enable <N>      - enable extension by index (1-based)
#
# Bisect workflow:
#   1. ./bisect_extensions.sh disable-all
#   2. Open project in Godot; if BV still fails, the problem is not a Rust extension.
#   3. ./bisect_extensions.sh enable 1
#   4. Open Godot again. If BV now fails, extension 1 is the culprit.
#   5. If BV works, enable 2, then 3, etc. until you find the one that breaks load.

set -e
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
GODOT_ADDONS="${SCRIPT_DIR}/../godot_source/addons"

if [[ ! -d "$GODOT_ADDONS" ]]; then
  echo "Addons directory not found: $GODOT_ADDONS"
  exit 1
fi

# Discover all .gdextension and .gdextension.off under addons (one level per addon)
list_extension_files() {
  find "$GODOT_ADDONS" -maxdepth 3 -type f \( -name "*.gdextension" -o -name "*.gdextension.off" \) | sort
}

status() {
  echo "Rust GDExtension status (godot_source/addons):"
  echo "----------------------------------------------"
  local idx=1
  while IFS= read -r f; do
    [[ -z "$f" ]] && continue
    local base
    base="$(basename "$f")"
    local rel="${f#$GODOT_ADDONS/}"
    if [[ "$base" == *.gdextension.off ]]; then
      echo "  $idx. [DISABLED] $rel"
    else
      echo "  $idx. [enabled]  $rel"
    fi
    ((idx++)) || true
  done < <(list_extension_files)
  echo ""
  echo "Use: disable <N> / enable <N> to toggle by index. disable-all / enable-all for all."
}

disable_all() {
  local count=0
  while IFS= read -r f; do
    [[ -z "$f" ]] && continue
    if [[ "$f" == *.gdextension ]]; then
      mv "$f" "${f}.off"
      echo "Disabled: ${f#$GODOT_ADDONS/}"
      ((count++)) || true
    fi
  done < <(list_extension_files)
  echo "Disabled $count extension(s). Open Godot to test."
}

enable_all() {
  local count=0
  while IFS= read -r f; do
    [[ -z "$f" ]] && continue
    if [[ "$f" == *.gdextension.off ]]; then
      mv "$f" "${f%.off}"
      echo "Enabled: ${f#$GODOT_ADDONS/}"
      ((count++)) || true
    fi
  done < <(list_extension_files)
  echo "Enabled $count extension(s)."
}

get_nth_path() {
  local n="$1"
  local idx=1
  while IFS= read -r f; do
    [[ -z "$f" ]] && continue
    if [[ $idx -eq $n ]]; then
      echo "$f"
      return
    fi
    ((idx++)) || true
  done < <(list_extension_files)
  echo ""
}

disable_nth() {
  local n="${1:-0}"
  if [[ ! "$n" =~ ^[0-9]+$ ]] || [[ $n -lt 1 ]]; then
    echo "Usage: $0 disable <N>   (N = 1-based index from 'status')"
    exit 1
  fi
  local path
  path="$(get_nth_path "$n")"
  if [[ -z "$path" ]]; then
    echo "No extension at index $n. Run 'status' to see indices."
    exit 1
  fi
  if [[ "$path" == *.gdextension.off ]]; then
    echo "Already disabled: $path"
    exit 0
  fi
  mv "$path" "${path}.off"
  echo "Disabled: ${path#$GODOT_ADDONS/}. Open Godot to test."
}

enable_nth() {
  local n="${1:-0}"
  if [[ ! "$n" =~ ^[0-9]+$ ]] || [[ $n -lt 1 ]]; then
    echo "Usage: $0 enable <N>   (N = 1-based index from 'status')"
    exit 1
  fi
  local path
  path="$(get_nth_path "$n")"
  if [[ -z "$path" ]]; then
    echo "No extension at index $n. Run 'status' to see indices."
    exit 1
  fi
  if [[ "$path" != *.gdextension.off ]]; then
    echo "Already enabled: $path"
    exit 0
  fi
  mv "$path" "${path%.off}"
  echo "Enabled: ${path#$GODOT_ADDONS/}."
}

case "${1:-status}" in
  status)     status ;;
  disable-all) disable_all ;;
  enable-all)  enable_all ;;
  disable)    disable_nth "$2" ;;
  enable)     enable_nth "$2" ;;
  *)
    echo "Usage: $0 { status | disable-all | enable-all | disable <N> | enable <N> }"
    exit 1
    ;;
esac
