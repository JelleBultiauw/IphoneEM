#!/bin/zsh
# sync-from-engine.sh — dev helper. Copies the GUI sources out of a working
# vphone-cli tree into overlay/ and regenerates the engine patches, so the
# repository stays the source of truth.
#
#   VPHONE_ENGINE=~/Projects/vphone-cli ./scripts/sync-from-engine.sh
set -euo pipefail

HERE="${0:A:h}/.."
ENGINE="${VPHONE_ENGINE:-$HOME/Projects/vphone-cli}"
[[ -d "$ENGINE/.git" ]] || { echo "engine not found at $ENGINE"; exit 1; }

echo "=== copying GUI sources ==="
rsync -a "$ENGINE"/sources/vphone-cli/EM*.swift "$HERE/overlay/sources/vphone-cli/"
ls "$HERE/overlay/sources/vphone-cli"

echo "=== regenerating patches ==="
git -C "$ENGINE" diff -- sources/vphone-cli/main.swift \
  > "$HERE/patches/0001-gui-entrypoint.patch"
git -C "$ENGINE" diff -- sources/vphone-cli/VPhoneVirtualMachine.swift \
  > "$HERE/patches/0002-guest-stop-guard.patch"
for patch in "$HERE"/patches/*.patch; do
  [[ -s "$patch" ]] || { echo "  warning: $(basename "$patch") is empty — did the engine change?"; }
done
echo "done — review with: git diff"
