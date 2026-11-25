#!/bin/sh
# Prints the xcodebuild destination for the simulator named $1 on the newest installed iOS
# runtime matching $2, which is a major version ("26") or an exact one ("26.5"). With no
# match it lists the available simulators and fails. CI uses it to turn its device and iOS
# inputs into `make test DESTINATION=...`, and it works the same locally.
set -eu

if [ $# -ne 2 ]; then
	echo "usage: $0 <device name> <iOS version>" >&2
	exit 2
fi
device=$1 ios=$2

# `simctl list` prints a "-- iOS 26.5 --" header, then lines like
# "    iPhone 17 (<UDID>) (Shutdown)". Device names can contain parentheses themselves.
match=$(xcrun simctl list devices available | awk -v device="$device" -v ios="$ios" '
	/^-- iOS / { version = $3; wanted = (version == ios || index(version, ios ".") == 1); next }
	/^-- / { wanted = 0; next }
	wanted && match($0, / \([0-9A-F-]+\) \([A-Za-z ]+\) *$/) {
		name = substr($0, 1, RSTART - 1)
		sub(/^ +/, "", name)
		if (name == device) print version, substr($0, RSTART + 2, 36)
	}' | sort -V | tail -1)

if [ -z "$match" ]; then
	echo "error: no available '$device' simulator on iOS $ios. Available iOS simulators:" >&2
	xcrun simctl list devices available | awk '/^-- iOS /{p = 1} /^-- / && !/^-- iOS /{p = 0} p' >&2
	exit 1
fi

echo "find-simulator: $device, iOS ${match% *}" >&2
echo "platform=iOS Simulator,id=${match#* }"
