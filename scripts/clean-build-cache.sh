#!/bin/sh
set -eu

ROOT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
MODE="dry-run"
OLDER_THAN_DAYS=""

usage() {
  cat <<EOF
Usage:
  scripts/clean-build-cache.sh [--execute] [--older-than DAYS]

Options:
  --execute          Delete matching generated files. Default is dry-run.
  --older-than DAYS  Only delete generated paths older than DAYS.
  --help            Show this help.

The script only targets repository-local build output and macOS metadata.
EOF
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --execute)
      MODE="execute"
      shift
      ;;
    --older-than)
      if [ "$#" -lt 2 ]; then
        echo "Missing value for --older-than" >&2
        exit 2
      fi
      OLDER_THAN_DAYS="$2"
      shift 2
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

case "$OLDER_THAN_DAYS" in
  ""|*[!0-9]*)
    if [ -n "$OLDER_THAN_DAYS" ]; then
      echo "--older-than must be a non-negative integer" >&2
      exit 2
    fi
    ;;
esac

targets="
BodyCoachApp/.build
BodyCoachCore/.build
BodyCoachCore/.clang-module-cache
BodyCoachCore/.swiftpm
BodyCoachCore/.local-home
.DS_Store
BodyCoachApp/.DS_Store
"

find_paths() {
  for target in $targets; do
    path="$ROOT_DIR/$target"
    [ -e "$path" ] || continue

    if [ -n "$OLDER_THAN_DAYS" ]; then
      find "$path" -prune -mtime +"$OLDER_THAN_DAYS" -print
    else
      printf '%s\n' "$path"
    fi
  done
}

paths="$(find_paths)"

if [ -z "$paths" ]; then
  echo "No generated cache paths matched."
  exit 0
fi

echo "Matched generated cache paths:"
printf '%s\n' "$paths"
echo

echo "Estimated size:"
printf '%s\n' "$paths" | while IFS= read -r path; do
  [ -n "$path" ] || continue
  du -sh "$path" 2>/dev/null || true
done
echo

if [ "$MODE" != "execute" ]; then
  echo "Dry-run only. Re-run with --execute to delete these paths."
  exit 0
fi

printf '%s\n' "$paths" | while IFS= read -r path; do
  [ -n "$path" ] || continue
  rm -rf -- "$path"
done

echo "Deleted generated cache paths."
