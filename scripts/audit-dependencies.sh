#!/bin/sh
# Fails when RideOrNah pulls in any remote package. The app ships Apple frameworks only;
# a third-party dependency needs a change whose design justifies it (see openspec/config.yaml).
set -eu
cd "$(dirname "$0")/.."

status=0

kit_deps=$(swift package show-dependencies --package-path Packages/RideOrNahKit --format flatlist)
if [ -n "$kit_deps" ]; then
	echo "error: RideOrNahKit depends on remote packages:" >&2
	echo "$kit_deps" >&2
	status=1
fi

# XcodeGen declares remote packages with `url:` or `github:`; local ones use `path:`.
if grep -nE '^[[:space:]]+(url|github):' project.yml >&2; then
	echo "error: project.yml declares a remote package (lines above)" >&2
	status=1
fi

if [ "$status" -eq 0 ]; then
	echo "audit: no remote package dependencies"
fi
exit "$status"
