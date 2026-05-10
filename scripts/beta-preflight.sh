#!/bin/sh
set -eu

ROOT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
PROJECT="$ROOT_DIR/BodyCoachApp/BodyCoachApp.xcodeproj"
APP_TARGET="BodyCoachApp"
WATCH_TARGET="BodyCoachWatch"
APP_SCHEME="BodyCoachApp"
RUN_BUILD=1
RUN_ARCHIVE=0
ARCHIVE_PATH="$ROOT_DIR/BodyCoachApp/.build/Archives/VitalLoop.xcarchive"

usage() {
  cat <<EOF
Usage:
  scripts/beta-preflight.sh [--skip-build] [--archive]

Options:
  --skip-build  Only check release metadata and signing readiness.
  --archive     Run a Release archive after metadata checks. Requires valid signing.
  --help        Show this help.
EOF
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --skip-build)
      RUN_BUILD=0
      shift
      ;;
    --archive)
      RUN_ARCHIVE=1
      shift
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

fail() {
  echo "Preflight failed: $1" >&2
  exit 1
}

require_file() {
  [ -f "$1" ] || fail "Missing $1"
}

setting_value() {
  key="$1"
  file="$2"
  awk -F= -v key="$key" '
    $1 ~ "^[[:space:]]*" key "[[:space:]]*$" {
      value = $2
      sub(/^[[:space:]]+/, "", value)
      sub(/[[:space:]]+$/, "", value)
      print value
      exit
    }
  ' "$file"
}

build_settings_file() {
  target="$1"
  output="$2"
  xcodebuild -project "$PROJECT" -target "$target" -showBuildSettings > "$output"
}

print_check() {
  printf '✓ %s\n' "$1"
}

command -v xcodebuild >/dev/null 2>&1 || fail "xcodebuild is not available"
require_file "$ROOT_DIR/BodyCoachApp/PrivacyInfo.xcprivacy"
require_file "$ROOT_DIR/BodyCoachApp/BodyCoachApp.entitlements"
require_file "$ROOT_DIR/BodyCoachApp/Shared/AppPrivacyLinks.swift"
require_file "$ROOT_DIR/site/privacy-policy.html"

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

app_settings="$tmp_dir/app-build-settings.txt"
watch_settings="$tmp_dir/watch-build-settings.txt"
build_settings_file "$APP_TARGET" "$app_settings"
build_settings_file "$WATCH_TARGET" "$watch_settings"

app_bundle_id="$(setting_value PRODUCT_BUNDLE_IDENTIFIER "$app_settings")"
watch_bundle_id="$(setting_value PRODUCT_BUNDLE_IDENTIFIER "$watch_settings")"
app_marketing_version="$(setting_value MARKETING_VERSION "$app_settings")"
watch_marketing_version="$(setting_value MARKETING_VERSION "$watch_settings")"
app_build_number="$(setting_value CURRENT_PROJECT_VERSION "$app_settings")"
watch_build_number="$(setting_value CURRENT_PROJECT_VERSION "$watch_settings")"
app_team="$(setting_value DEVELOPMENT_TEAM "$app_settings")"
watch_team="$(setting_value DEVELOPMENT_TEAM "$watch_settings")"
privacy_url="$(awk -F\" '/privacyPolicyURL/ { print $2; exit }' "$ROOT_DIR/BodyCoachApp/Shared/AppPrivacyLinks.swift")"

[ -n "$app_bundle_id" ] || fail "iPhone bundle id is empty"
[ -n "$watch_bundle_id" ] || fail "Watch bundle id is empty"
[ -n "$app_marketing_version" ] || fail "iPhone marketing version is empty"
[ -n "$watch_marketing_version" ] || fail "Watch marketing version is empty"
[ -n "$app_build_number" ] || fail "iPhone build number is empty"
[ -n "$watch_build_number" ] || fail "Watch build number is empty"
[ "$app_marketing_version" = "$watch_marketing_version" ] || fail "iPhone and Watch marketing versions do not match"
[ "$app_build_number" = "$watch_build_number" ] || fail "iPhone and Watch build numbers do not match"

case "$privacy_url" in
  https://*)
    ;;
  *)
    fail "Privacy policy URL must be an https URL"
    ;;
esac

grep -q "NSPrivacyTracking" "$ROOT_DIR/BodyCoachApp/PrivacyInfo.xcprivacy" || fail "Privacy manifest is missing NSPrivacyTracking"
grep -q "NSPrivacyAccessedAPICategoryUserDefaults" "$ROOT_DIR/BodyCoachApp/PrivacyInfo.xcprivacy" || fail "Privacy manifest is missing UserDefaults required reason API"
grep -q "com.apple.developer.healthkit" "$ROOT_DIR/BodyCoachApp/BodyCoachApp.entitlements" || fail "HealthKit entitlement is missing"
grep -q "VitalLoop is not a medical device" "$ROOT_DIR/site/privacy-policy.html" || fail "Privacy policy is missing medical disclaimer"

print_check "iPhone bundle id: $app_bundle_id"
print_check "Watch bundle id: $watch_bundle_id"
print_check "Version: $app_marketing_version ($app_build_number)"
print_check "Privacy policy URL: $privacy_url"
print_check "Privacy manifest and HealthKit entitlement are present"

if [ -z "$app_team" ] || [ -z "$watch_team" ]; then
  echo "Warning: DEVELOPMENT_TEAM is not set for one or more targets. Set the official Apple Developer Team before archiving for TestFlight."
else
  print_check "Development team configured for iPhone and Watch targets"
fi

if [ "$RUN_BUILD" -eq 1 ]; then
  "$ROOT_DIR/scripts/verify-local.sh"
fi

echo
echo "Release archive command:"
printf 'xcodebuild -project "%s" -scheme "%s" -configuration Release -destination "generic/platform=iOS" -archivePath "%s" archive\n' "$PROJECT" "$APP_SCHEME" "$ARCHIVE_PATH"

if [ "$RUN_ARCHIVE" -eq 1 ]; then
  mkdir -p "$(dirname "$ARCHIVE_PATH")"
  xcodebuild \
    -project "$PROJECT" \
    -scheme "$APP_SCHEME" \
    -configuration Release \
    -destination "generic/platform=iOS" \
    -archivePath "$ARCHIVE_PATH" \
    archive
fi

echo
echo "Beta preflight passed."
