#!/bin/bash
# Archives a Release build, uploads it to App Store Connect, waits for processing and gives it
# to the internal TestFlight group. `make testflight` runs it on the owner's Mac, and
# .github/workflows/testflight.yml runs it in CI.
#
# Signing is Xcode's automatic signing with a cloud-managed distribution certificate. On a Mac
# it uses the Apple Account signed in to Xcode, and asc uses its keychain profile. In CI, set
# ASC_KEY_ID, ASC_ISSUER_ID and ASC_PRIVATE_KEY_PATH (the .p8 file), and both authenticate with
# that API key instead.
set -euo pipefail
cd "$(dirname "$0")/.."

GROUP="Ride or Nah Team"
OUT=build/testflight
export ASC_TELEMETRY_DISABLED=1

make project

# The identity and version come from the build settings, so Local.xcconfig overrides apply.
settings=$(xcodebuild -showBuildSettings -project RideOrNah.xcodeproj -scheme RideOrNah -configuration Release \
    2>/dev/null)
setting() { awk -v key="$1" '$1 == key && $2 == "=" { print $3; exit }' <<<"$settings"; }
bundle_id=$(setting APP_BUNDLE_ID)
version=$(setting MARKETING_VERSION)

app=$(asc apps list --bundle-id "$bundle_id" --output json | jq -r '.data[0].id // empty')
if [ -z "$app" ]; then
    echo "error: App Store Connect has no app record for $bundle_id. The owner creates it first;" \
        "see \"TestFlight\" in docs/app-store-connect.md." >&2
    exit 1
fi

# One above the highest build App Store Connect has seen for the app, uploaded or processed.
build=$(asc builds next-build-number --app "$app" --platform IOS --output json | jq -r .nextBuildNumber)
echo "Archiving Ride or Nah $version ($build) for $bundle_id"

auth=()
if [ -n "${ASC_PRIVATE_KEY_PATH:-}" ]; then
    auth=(-authenticationKeyPath "$ASC_PRIVATE_KEY_PATH" -authenticationKeyID "$ASC_KEY_ID"
        -authenticationKeyIssuerID "$ASC_ISSUER_ID")
fi

rm -rf "$OUT"
xcodebuild archive -quiet -project RideOrNah.xcodeproj -scheme RideOrNah -configuration Release \
    -destination generic/platform=iOS -archivePath "$OUT/RideOrNah.xcarchive" \
    CURRENT_PROJECT_VERSION="$build" -allowProvisioningUpdates ${auth[@]+"${auth[@]}"}
xcodebuild -exportArchive -quiet -archivePath "$OUT/RideOrNah.xcarchive" \
    -exportOptionsPlist Config/ExportOptions.plist -exportPath "$OUT/export" \
    -allowProvisioningUpdates ${auth[@]+"${auth[@]}"}

echo "Uploading build $build and waiting for App Store Connect to process it"
asc builds upload --app "$app" --ipa "$OUT/export/RideOrNah.ipa" --wait --output json >"$OUT/upload.json"

# An internal group with access to all builds gets each one automatically, and App Store Connect
# refuses to add it by hand. Only a group without that access needs the build added.
all_builds=$(asc testflight groups list --app "$app" --internal --output json |
    jq -r --arg group "$GROUP" '.data[] | select(.attributes.name == $group) | .attributes.hasAccessToAllBuilds')
case $all_builds in
true) ;;
false) asc builds add-groups --app "$app" --build-number "$build" --platform IOS --group "$GROUP" >/dev/null ;;
*)
    echo "error: the build uploaded, but the app has no internal TestFlight group \"$GROUP\"." >&2
    exit 1
    ;;
esac
echo "Ride or Nah $version ($build) is in TestFlight for \"$GROUP\"."
