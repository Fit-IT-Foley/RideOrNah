#!/bin/sh
# Creates the simulators `make test` runs on, if they don't exist yet:
# "RideOrNah iOS 26" (oldest supported OS),
# "RideOrNah iOS 27" (newest iOS that runs the device type) and
# "RideOrNah watchOS 27" (newest watchOS, for the watch app's UI tests).
set -eu

create() {
	name=$1 device_type=$2 runtime_pattern=$3
	if xcrun simctl list devices available | grep -q "    $name ("; then
		echo "simulators: $name exists"
		return
	fi
	# Newest matching runtime first; some runtimes only support certain device types.
	for runtime in $(xcrun simctl list runtimes available | grep -E "$runtime_pattern" | sed 's/.* - //' | sort -r); do
		if xcrun simctl create "$name" "$device_type" "$runtime" >/dev/null 2>&1; then
			echo "simulators: created $name ($device_type, $runtime)"
			return
		fi
	done
	echo "simulators: no installed runtime matching '$runtime_pattern' runs $device_type; skipping $name" >&2
}

create "RideOrNah iOS 26" "iPhone 17" '^iOS 26\.'
create "RideOrNah iOS 27" "iPhone 17 Pro" '^iOS 27\.'
create "RideOrNah watchOS 27" "Apple Watch Series 11 (46mm)" '^watchOS 27\.'
