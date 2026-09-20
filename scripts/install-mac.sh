#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/.."

DATASET="Sources/Datashard/Resources/cp2077-reader.sqlite"
APP="xtool/Datashard.app"

# Xcode 26.4 and newer default SwiftPM to the Swift Build layout, which xtool
# does not look in yet; point the path it expects at the one that exists.
link_build_products() {
    local products
    products="$(swift build --swift-sdk arm64-apple-ios --show-bin-path 2>/dev/null | tail -1)"
    case "$products" in
        */out/Products/*)
            mkdir -p .build/arm64-apple-ios
            ln -sfn "$products" .build/arm64-apple-ios/debug
            ;;
    esac
}

# The phone to install onto: $1, else the only connected device.
resolve_device() {
    if [ $# -gt 0 ]; then
        echo "$1"
        return
    fi
    local found
    found="$(xcrun devicectl list devices 2>/dev/null | grep -E 'iPhone|iPad' |
        grep available |
        grep -oE '[0-9A-F]{8}(-[0-9A-F]{4}){3}-[0-9A-F]{12}')"
    if [ "$(echo "$found" | grep -c .)" -ne 1 ]; then
        echo "pass a device identifier; xcrun devicectl list devices shows:" >&2
        xcrun devicectl list devices >&2
        exit 1
    fi
    echo "$found"
}

require_dataset() {
    if [ ! -f "$DATASET" ]; then
        echo "missing $DATASET" >&2
        echo "build it on a Linux box with cpdb, then copy it here:" >&2
        echo "  cpdb build \"/path/to/Cyberpunk 2077\" cp2077.sqlite --images" >&2
        echo "  cpdb cp2077.sqlite export $DATASET" >&2
        exit 1
    fi
}

require_dataset
device="$(resolve_device "$@")"
link_build_products
xtool dev build --sign
bundle_id="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$APP/Info.plist")"
xcrun devicectl device install app --device "$device" "$APP"
xcrun devicectl device process launch --device "$device" "$bundle_id"
