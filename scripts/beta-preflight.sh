#!/bin/sh
set -eu

ROOT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
PROJECT="$ROOT_DIR/BodyCoachApp/BodyCoachApp.xcodeproj"
APP_TARGET="BodyCoachApp"
WATCH_TARGET="BodyCoachWatch"
APP_SCHEME="BodyCoachApp"
RUN_BUILD=1
RUN_ARCHIVE=0
RUN_EXPORT=0
RUN_UPLOAD=0
ALLOW_PROVISIONING_UPDATES=0
ARCHIVE_PATH="$ROOT_DIR/BodyCoachApp/.build/Archives/VitalLoop.xcarchive"
EXPORT_PATH="$ROOT_DIR/BodyCoachApp/.build/Exports/TestFlight"
EXPORT_OPTIONS_PLIST="$ROOT_DIR/BodyCoachApp/ExportOptions-TestFlight.plist"
IOS_APP_ICON_DIR="$ROOT_DIR/BodyCoachApp/Assets.xcassets/AppIcon.appiconset"
WATCH_APP_ICON_DIR="$ROOT_DIR/BodyCoachApp/WatchAssets.xcassets/AppIcon.appiconset"
API_KEY_PATH=""
API_KEY_ID=""
API_KEY_ISSUER_ID=""

usage() {
  cat <<EOF
Usage:
  scripts/beta-preflight.sh [--skip-build] [--archive] [--export] [--upload]

Options:
  --skip-build                  Only check release metadata and signing readiness.
  --archive                     Run a Release archive after metadata checks. Requires valid signing.
  --export                      Archive, then export an App Store Connect IPA locally.
  --upload                      Archive, then upload the build to App Store Connect.
  --allow-provisioning-updates  Allow Xcode to create or update signing assets.
  --export-path PATH            Exported IPA/output directory. Defaults to BodyCoachApp/.build/Exports/TestFlight.
  --api-key-path PATH           App Store Connect API private key path for xcodebuild.
  --api-key-id ID               App Store Connect API key id.
  --api-key-issuer-id ID        App Store Connect issuer id.
  --help                        Show this help.
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
    --export)
      RUN_ARCHIVE=1
      RUN_EXPORT=1
      shift
      ;;
    --upload)
      RUN_ARCHIVE=1
      RUN_UPLOAD=1
      shift
      ;;
    --allow-provisioning-updates)
      ALLOW_PROVISIONING_UPDATES=1
      shift
      ;;
    --export-path)
      [ "$#" -gt 1 ] || {
        echo "Missing value for --export-path" >&2
        usage >&2
        exit 2
      }
      EXPORT_PATH="$2"
      shift 2
      ;;
    --api-key-path)
      [ "$#" -gt 1 ] || {
        echo "Missing value for --api-key-path" >&2
        usage >&2
        exit 2
      }
      API_KEY_PATH="$2"
      shift 2
      ;;
    --api-key-id)
      [ "$#" -gt 1 ] || {
        echo "Missing value for --api-key-id" >&2
        usage >&2
        exit 2
      }
      API_KEY_ID="$2"
      shift 2
      ;;
    --api-key-issuer-id)
      [ "$#" -gt 1 ] || {
        echo "Missing value for --api-key-issuer-id" >&2
        usage >&2
        exit 2
      }
      API_KEY_ISSUER_ID="$2"
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

run_xcodebuild() {
  if [ "$ALLOW_PROVISIONING_UPDATES" -eq 1 ]; then
    set -- "$@" -allowProvisioningUpdates
  fi

  if [ -n "$API_KEY_PATH" ]; then
    set -- "$@" \
      -authenticationKeyPath "$API_KEY_PATH" \
      -authenticationKeyID "$API_KEY_ID" \
      -authenticationKeyIssuerID "$API_KEY_ISSUER_ID"
  fi

  "$@"
}

prepare_export_options() {
  output="$1"
  cp "$EXPORT_OPTIONS_PLIST" "$output"

  if [ "$RUN_UPLOAD" -eq 1 ]; then
    /usr/libexec/PlistBuddy -c "Set :destination upload" "$output" >/dev/null
  else
    /usr/libexec/PlistBuddy -c "Set :destination export" "$output" >/dev/null
  fi
}

png_property() {
  property="$1"
  file="$2"
  sips -g "$property" "$file" 2>/dev/null | awk -v key="$property:" '$1 == key { print $2; exit }'
}

require_png_size_no_alpha() {
  file="$1"
  expected_width="$2"
  expected_height="$3"

  require_file "$file"

  width="$(png_property pixelWidth "$file")"
  height="$(png_property pixelHeight "$file")"
  has_alpha="$(png_property hasAlpha "$file")"

  [ "$width" = "$expected_width" ] || fail "$file must be ${expected_width}px wide, got ${width:-unknown}"
  [ "$height" = "$expected_height" ] || fail "$file must be ${expected_height}px high, got ${height:-unknown}"
  [ "$has_alpha" = "no" ] || fail "$file must not contain an alpha channel"
}

require_watch_rendition() {
  asset_info="$1"
  filename="$2"
  grep -q "\"RenditionName\" : \"$filename\"" "$asset_info" || fail "Watch app icon $filename is not present in compiled Assets.car"
}

validate_app_icons() {
  require_file "$IOS_APP_ICON_DIR/Contents.json"
  require_file "$WATCH_APP_ICON_DIR/Contents.json"

  require_png_size_no_alpha "$IOS_APP_ICON_DIR/AppIcon-iPhone-20@2x.png" 40 40
  require_png_size_no_alpha "$IOS_APP_ICON_DIR/AppIcon-iPhone-20@3x.png" 60 60
  require_png_size_no_alpha "$IOS_APP_ICON_DIR/AppIcon-iPhone-29@2x.png" 58 58
  require_png_size_no_alpha "$IOS_APP_ICON_DIR/AppIcon-iPhone-29@3x.png" 87 87
  require_png_size_no_alpha "$IOS_APP_ICON_DIR/AppIcon-iPhone-40@2x.png" 80 80
  require_png_size_no_alpha "$IOS_APP_ICON_DIR/AppIcon-iPhone-40@3x.png" 120 120
  require_png_size_no_alpha "$IOS_APP_ICON_DIR/AppIcon-60@2x.png" 120 120
  require_png_size_no_alpha "$IOS_APP_ICON_DIR/AppIcon-60@3x.png" 180 180
  require_png_size_no_alpha "$IOS_APP_ICON_DIR/AppIcon-1024.png" 1024 1024

  require_png_size_no_alpha "$WATCH_APP_ICON_DIR/AppIcon-24@2x.png" 48 48
  require_png_size_no_alpha "$WATCH_APP_ICON_DIR/AppIcon-27.5@2x.png" 55 55
  require_png_size_no_alpha "$WATCH_APP_ICON_DIR/AppIcon-29@2x.png" 58 58
  require_png_size_no_alpha "$WATCH_APP_ICON_DIR/AppIcon-29@3x.png" 87 87
  require_png_size_no_alpha "$WATCH_APP_ICON_DIR/AppIcon-40@2x.png" 80 80
  require_png_size_no_alpha "$WATCH_APP_ICON_DIR/AppIcon-44@2x.png" 88 88
  require_png_size_no_alpha "$WATCH_APP_ICON_DIR/AppIcon-50@2x.png" 100 100
  require_png_size_no_alpha "$WATCH_APP_ICON_DIR/AppIcon-86@2x.png" 172 172
  require_png_size_no_alpha "$WATCH_APP_ICON_DIR/AppIcon-98@2x.png" 196 196
  require_png_size_no_alpha "$WATCH_APP_ICON_DIR/AppIcon-108@2x.png" 216 216
  require_png_size_no_alpha "$WATCH_APP_ICON_DIR/AppIcon-1024.png" 1024 1024

  watch_compile_dir="$tmp_dir/watch-icons"
  watch_info_plist="$tmp_dir/watch-icons-info.plist"
  watch_asset_info="$tmp_dir/watch-assets.txt"
  mkdir -p "$watch_compile_dir"
  xcrun actool "$ROOT_DIR/BodyCoachApp/WatchAssets.xcassets" \
    --compile "$watch_compile_dir" \
    --platform watchos \
    --minimum-deployment-target 10.0 \
    --app-icon AppIcon \
    --output-partial-info-plist "$watch_info_plist" \
    --output-format human-readable-text >/dev/null
  xcrun assetutil --info "$watch_compile_dir/Assets.car" > "$watch_asset_info"

  require_watch_rendition "$watch_asset_info" "AppIcon-24@2x.png"
  require_watch_rendition "$watch_asset_info" "AppIcon-27.5@2x.png"
  require_watch_rendition "$watch_asset_info" "AppIcon-29@2x.png"
  require_watch_rendition "$watch_asset_info" "AppIcon-29@3x.png"
  require_watch_rendition "$watch_asset_info" "AppIcon-40@2x.png"
  require_watch_rendition "$watch_asset_info" "AppIcon-44@2x.png"
  require_watch_rendition "$watch_asset_info" "AppIcon-50@2x.png"
  require_watch_rendition "$watch_asset_info" "AppIcon-86@2x.png"
  require_watch_rendition "$watch_asset_info" "AppIcon-98@2x.png"
  require_watch_rendition "$watch_asset_info" "AppIcon-108@2x.png"
  require_watch_rendition "$watch_asset_info" "AppIcon-1024.png"
}

[ "$RUN_EXPORT" -eq 0 ] || [ "$RUN_UPLOAD" -eq 0 ] || fail "Use either --export or --upload, not both"

if [ -n "$API_KEY_PATH$API_KEY_ID$API_KEY_ISSUER_ID" ]; then
  [ -n "$API_KEY_PATH" ] || fail "--api-key-path is required when using App Store Connect API key authentication"
  [ -n "$API_KEY_ID" ] || fail "--api-key-id is required when using App Store Connect API key authentication"
  [ -n "$API_KEY_ISSUER_ID" ] || fail "--api-key-issuer-id is required when using App Store Connect API key authentication"
  require_file "$API_KEY_PATH"
fi

command -v xcodebuild >/dev/null 2>&1 || fail "xcodebuild is not available"
require_file "$ROOT_DIR/BodyCoachApp/PrivacyInfo.xcprivacy"
require_file "$ROOT_DIR/BodyCoachApp/BodyCoachApp.entitlements"
require_file "$ROOT_DIR/BodyCoachApp/Shared/AppPrivacyLinks.swift"
require_file "$ROOT_DIR/site/index.html"
require_file "$ROOT_DIR/site/privacy-policy.html"
require_file "$ROOT_DIR/site/support.html"
require_file "$EXPORT_OPTIONS_PLIST"

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
marketing_url="$(awk -F\" '/marketingURL/ { print $2; exit }' "$ROOT_DIR/BodyCoachApp/Shared/AppPrivacyLinks.swift")"
privacy_url="$(awk -F\" '/privacyPolicyURL/ { print $2; exit }' "$ROOT_DIR/BodyCoachApp/Shared/AppPrivacyLinks.swift")"
support_url="$(awk -F\" '/supportURL/ { print $2; exit }' "$ROOT_DIR/BodyCoachApp/Shared/AppPrivacyLinks.swift")"
export_method="$(/usr/libexec/PlistBuddy -c "Print :method" "$EXPORT_OPTIONS_PLIST" 2>/dev/null || true)"
export_team="$(/usr/libexec/PlistBuddy -c "Print :teamID" "$EXPORT_OPTIONS_PLIST" 2>/dev/null || true)"
app_health_share_usage="$(setting_value INFOPLIST_KEY_NSHealthShareUsageDescription "$app_settings")"
app_health_update_usage="$(setting_value INFOPLIST_KEY_NSHealthUpdateUsageDescription "$app_settings")"

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

case "$marketing_url" in
  https://*)
    ;;
  *)
    fail "Marketing URL must be an https URL"
    ;;
esac

case "$support_url" in
  https://*)
    ;;
  *)
    fail "Support URL must be an https URL"
    ;;
esac

grep -q "NSPrivacyTracking" "$ROOT_DIR/BodyCoachApp/PrivacyInfo.xcprivacy" || fail "Privacy manifest is missing NSPrivacyTracking"
grep -q "NSPrivacyAccessedAPICategoryUserDefaults" "$ROOT_DIR/BodyCoachApp/PrivacyInfo.xcprivacy" || fail "Privacy manifest is missing UserDefaults required reason API"
grep -q "com.apple.developer.healthkit" "$ROOT_DIR/BodyCoachApp/BodyCoachApp.entitlements" || fail "HealthKit entitlement is missing"
[ -n "$app_health_share_usage" ] || fail "iPhone Info.plist is missing NSHealthShareUsageDescription"
[ -n "$app_health_update_usage" ] || fail "iPhone Info.plist is missing NSHealthUpdateUsageDescription"
grep -q "VitalLoop is not a medical device" "$ROOT_DIR/site/privacy-policy.html" || fail "Privacy policy is missing medical disclaimer"
grep -q "VitalLoop is not a medical device" "$ROOT_DIR/site/index.html" || fail "Marketing page is missing medical disclaimer"
grep -q "github.com/jhb175/vitalloop/issues" "$ROOT_DIR/site/support.html" || fail "Support page is missing GitHub Issues support link"
[ "$export_method" = "app-store-connect" ] || fail "TestFlight export method must be app-store-connect"
validate_app_icons

print_check "iPhone bundle id: $app_bundle_id"
print_check "Watch bundle id: $watch_bundle_id"
print_check "Version: $app_marketing_version ($app_build_number)"
print_check "Marketing URL: $marketing_url"
print_check "Privacy policy URL: $privacy_url"
print_check "Support URL: $support_url"
print_check "Privacy manifest and HealthKit entitlement are present"
print_check "iPhone and Apple Watch app icons are complete and opaque"

if [ -z "$app_team" ] || [ -z "$watch_team" ]; then
  echo "Warning: DEVELOPMENT_TEAM is not set for one or more targets. Set the official Apple Developer Team before archiving for TestFlight."
else
  print_check "Development team configured for iPhone and Watch targets"
fi

if [ "$RUN_EXPORT" -eq 1 ] || [ "$RUN_UPLOAD" -eq 1 ]; then
  [ -n "$app_team" ] || fail "iPhone DEVELOPMENT_TEAM is required for TestFlight export or upload"
  [ -n "$watch_team" ] || fail "Watch DEVELOPMENT_TEAM is required for TestFlight export or upload"
  [ "$app_team" = "$watch_team" ] || fail "iPhone and Watch DEVELOPMENT_TEAM values do not match"
  [ "$export_team" = "$app_team" ] || fail "ExportOptions-TestFlight.plist teamID does not match DEVELOPMENT_TEAM"
  print_check "TestFlight export options ready"
fi

if [ "$RUN_BUILD" -eq 1 ]; then
  "$ROOT_DIR/scripts/verify-local.sh"
fi

echo
echo "Release archive command:"
printf 'xcodebuild -project "%s" -scheme "%s" -configuration Release -destination "generic/platform=iOS" -archivePath "%s" archive\n' "$PROJECT" "$APP_SCHEME" "$ARCHIVE_PATH"
echo
echo "TestFlight commands:"
echo "scripts/beta-preflight.sh --archive --allow-provisioning-updates"
echo "scripts/beta-preflight.sh --export --allow-provisioning-updates"
echo "scripts/beta-preflight.sh --upload --allow-provisioning-updates"

if [ "$RUN_ARCHIVE" -eq 1 ]; then
  mkdir -p "$(dirname "$ARCHIVE_PATH")"
  run_xcodebuild xcodebuild \
    -project "$PROJECT" \
    -scheme "$APP_SCHEME" \
    -configuration Release \
    -destination "generic/platform=iOS" \
    -archivePath "$ARCHIVE_PATH" \
    archive
fi

if [ "$RUN_EXPORT" -eq 1 ] || [ "$RUN_UPLOAD" -eq 1 ]; then
  [ -d "$ARCHIVE_PATH" ] || fail "Archive was not created at $ARCHIVE_PATH"
  mkdir -p "$EXPORT_PATH"
  export_options="$tmp_dir/ExportOptions-TestFlight.plist"
  prepare_export_options "$export_options"
  run_xcodebuild xcodebuild \
    -exportArchive \
    -archivePath "$ARCHIVE_PATH" \
    -exportPath "$EXPORT_PATH" \
    -exportOptionsPlist "$export_options"
fi

echo
echo "Beta preflight passed."
