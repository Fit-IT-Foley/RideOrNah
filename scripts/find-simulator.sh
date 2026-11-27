#!/bin/sh
# Prints the xcodebuild destination for the simulator named $1 on the newest installed runtime
# matching $2, which is a major version ("26") or an exact one ("26.5"). $3 is the platform,
# iOS unless given ("watchOS"). With no match it lists the available simulators for that
# platform and fails. CI uses it to turn its device and OS inputs into
# `make test DESTINATION=...`, and it works the same locally.
set -eu

if [ $# -lt 2 ] || [ $# -gt 3 ]; then
	echo "usage: $0 <device name> <OS version> [iOS|watchOS]" >&2
	exit 2
fi
device=$1 os=$2 platform=${3:-iOS}

# `simctl list` prints a "-- iOS 26.5 --" header, then lines like
# "    iPhone 17 (<UDID>) (Shutdown)". Device names can contain parentheses themselves.
match=$(xcrun simctl list devices available | awk -v device="$device" -v os="$os" -v platform="$platform" '
	/^-- / && $2 == platform { version = $3; wanted = (version == os || index(version, os ".") == 1); next }
	/^-- / { wanted = 0; next }
	wanted && match($0, / \([0-9A-F-]+\) \([A-Za-z ]+\) *$/) {
		name = substr($0, 1, RSTART - 1)
		sub(/^ +/, "", name)
		if (name == device) print version, substr($0, RSTART + 2, 36)
	}' | sort -V | tail -1)

if [ -z "$match" ]; then
	echo "error: no available '$device' simulator on $platform $os. Available $platform simulators:" >&2
	xcrun simctl list devices available | awk -v platform="$platform" '/^-- / {p = ($2 == platform)} p' >&2
	exit 1
fi

echo "find-simulator: $device, $platform ${match% *}" >&2
echo "platform=$platform Simulator,id=${match#* }"
