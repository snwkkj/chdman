#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
CHDMAN="${CHDMAN_BIN:-}"
OUT_DIR="${CHDMAN_OUT_DIR:-$SCRIPT_DIR/converted}"

if [[ -z "$CHDMAN" ]]; then
  if command -v chdman >/dev/null 2>&1; then
    CHDMAN="$(command -v chdman)"
  fi
fi

usage() {
  cat <<USAGE
Usage:
  bash iso2chd.sh
  bash iso2chd.sh file.iso [another-file.iso ...]
  bash iso2chd.sh /path/to/folder

Supported formats:
  .iso, .cue, .gdi

When no input is provided, this script converts supported files from:
  $SCRIPT_DIR

CHD files will be saved in:
  $OUT_DIR

You can change the chdman binary or output folder like this:
  CHDMAN_BIN=/data/data/com.termux/files/usr/bin/chdman bash iso2chd.sh game.iso
  CHDMAN_OUT_DIR=/sdcard/CHD bash iso2chd.sh game.iso
USAGE
}

[[ -x "$CHDMAN" ]] || {
  echo "Could not find chdman at: $CHDMAN" >&2
  echo "Set CHDMAN_BIN=/path/to/chdman or install chdman into the Termux PATH." >&2
  exit 1
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

mkdir -p "$OUT_DIR"

convert_one() {
  local input="$1"
  local base output

  case "${input,,}" in
    *.iso|*.cue|*.gdi) ;;
    *)
      echo "Skipping unsupported format: $input" >&2
      return 0
      ;;
  esac

  [[ -f "$input" ]] || {
    echo "Skipping, not a file: $input" >&2
    return 0
  }

  base="$(basename "$input")"
  output="$OUT_DIR/${base%.*}.chd"

  if [[ -e "$output" ]]; then
    echo "Already exists, skipping: $output"
    return 0
  fi

  echo "Converting: $input"
  "$CHDMAN" createcd -i "$input" -o "$output"
  echo "Saved to: $output"
}

if [[ "$#" -eq 0 ]]; then
  set -- "$SCRIPT_DIR"
fi

for item in "$@"; do
  if [[ -d "$item" ]]; then
    while IFS= read -r -d '' file; do
      convert_one "$file"
    done < <(find "$item" -type f \( -iname '*.iso' -o -iname '*.cue' -o -iname '*.gdi' \) -print0)
  else
    convert_one "$item"
  fi
done
