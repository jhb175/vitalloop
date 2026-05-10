#!/bin/sh
set -eu

ROOT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
PROJECT_FILE="$ROOT_DIR/BodyCoachApp/BodyCoachApp.xcodeproj/project.pbxproj"

usage() {
  cat <<EOF
Usage:
  scripts/bump-build-number.sh [NEXT_BUILD_NUMBER]

Without NEXT_BUILD_NUMBER, increments the current shared iPhone/watchOS build number by 1.
EOF
}

fail() {
  echo "Build number bump failed: $1" >&2
  exit 1
}

case "${1:-}" in
  --help|-h)
    usage
    exit 0
    ;;
esac

[ "$#" -le 1 ] || {
  usage >&2
  exit 2
}

[ -f "$PROJECT_FILE" ] || fail "Missing $PROJECT_FILE"

current_numbers="$(awk -F= '
  /CURRENT_PROJECT_VERSION/ {
    value = $2
    gsub(/[ ;]/, "", value)
    print value
  }
' "$PROJECT_FILE" | sort -u)"

current_count="$(printf '%s\n' "$current_numbers" | sed '/^$/d' | wc -l | tr -d ' ')"
[ "$current_count" = "1" ] || fail "Expected one shared CURRENT_PROJECT_VERSION, found: $current_numbers"

current_number="$(printf '%s\n' "$current_numbers" | sed -n '1p')"
case "$current_number" in
  ''|*[!0-9]*)
    fail "Current build number is not numeric: $current_number"
    ;;
esac

if [ "$#" -eq 1 ]; then
  next_number="$1"
else
  next_number=$((current_number + 1))
fi

case "$next_number" in
  ''|*[!0-9]*)
    fail "Next build number must be numeric: $next_number"
    ;;
esac

[ "$next_number" -gt "$current_number" ] || fail "Next build number must be greater than $current_number"

tmp_file="$(mktemp)"
trap 'rm -f "$tmp_file"' EXIT

sed "s/CURRENT_PROJECT_VERSION = $current_number;/CURRENT_PROJECT_VERSION = $next_number;/g" "$PROJECT_FILE" > "$tmp_file"
mv "$tmp_file" "$PROJECT_FILE"

updated_count="$(awk -F= '
  /CURRENT_PROJECT_VERSION/ {
    value = $2
    gsub(/[ ;]/, "", value)
    if (value == expected) {
      count += 1
    }
  }
  END { print count + 0 }
' expected="$next_number" "$PROJECT_FILE")"

[ "$updated_count" = "4" ] || fail "Expected to update 4 build settings, updated $updated_count"

printf 'Bumped CURRENT_PROJECT_VERSION from %s to %s\n' "$current_number" "$next_number"
