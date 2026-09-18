#!/bin/zsh
# build.sh - build iPhoneEM and install it into /Applications.
#
#   ./build.sh                 fetch the pinned engine, apply the GUI, build, install
#   ./build.sh --no-install    only produce dist/iPhoneEM.app
#   VPHONE_ENGINE=~/path ./build.sh   use an existing vphone-cli checkout
#
# The engine (Lakr233/vphone-cli, MIT) is pinned to a known-good commit; the GUI
# lives in overlay/ + patches/ so the engine stays untouched upstream.
set -euo pipefail

HERE="${0:A:h}"
ENGINE_REF="c2ae6d7c537236d3e91274162407cdb89ddfc353"
ENGINE_DIR="${VPHONE_ENGINE:-$HERE/.build/engine}"
BUILD_DIR="$HERE/.build"
DIST="$HERE/dist"
APP="$DIST/iPhoneEM.app"
ENTITLEMENTS="$ENGINE_DIR/sources/vphone.entitlements"
INSTALL=1
[[ "${1:-}" == "--no-install" ]] && INSTALL=0

echo "=== [1/6] engine ($ENGINE_REF) ==="
if [[ ! -d "$ENGINE_DIR/.git" ]]; then
  git clone https://github.com/Lakr233/vphone-cli.git "$ENGINE_DIR"
fi
if [[ -z "${VPHONE_ENGINE:-}" ]]; then
  git -C "$ENGINE_DIR" fetch --quiet origin "$ENGINE_REF" || true
  git -C "$ENGINE_DIR" checkout --quiet "$ENGINE_REF"
  git -C "$ENGINE_DIR" submodule update --init --recursive --depth 1
fi
[[ -f "$ENTITLEMENTS" ]] || { echo "missing $ENTITLEMENTS"; exit 1; }

echo "=== [2/6] apply GUI overlay ==="
cp -f "$HERE"/overlay/sources/vphone-cli/*.swift "$ENGINE_DIR/sources/vphone-cli/"
for patch in "$HERE"/patches/*.patch; do
  if git -C "$ENGINE_DIR" apply --reverse --check "$patch" 2>/dev/null; then
    echo "  $(basename "$patch"): already applied"
  else
    git -C "$ENGINE_DIR" apply "$patch"
    echo "  $(basename "$patch"): applied"
  fi
done

if [[ ! -f "$ENGINE_DIR/sources/vphone-cli/VPhoneBuildInfo.swift" ]]; then
  GIT_HASH="$(git -C "$ENGINE_DIR" rev-parse --short HEAD 2>/dev/null || echo unknown)"
  echo '// Auto-generated - do not edit' > "$ENGINE_DIR/sources/vphone-cli/VPhoneBuildInfo.swift"
  echo "enum VPhoneBuildInfo { static let commitHash = \"${GIT_HASH}\" }" >> "$ENGINE_DIR/sources/vphone-cli/VPhoneBuildInfo.swift"
fi

echo "=== [3/6] swift build (release) ==="
cd "$ENGINE_DIR"
swift build -c release
codesign --force --sign - --entitlements "$ENTITLEMENTS" .build/release/vphone-cli

echo "=== [4/6] vphoned guest daemon ==="
mkdir -p "$BUILD_DIR"
if [[ ! -f "$BUILD_DIR/vphoned.signed" ]]; then
  if command -v ldid >/dev/null 2>&1; then
    GIT_HASH="$(git -C "$ENGINE_DIR" rev-parse --short HEAD 2>/dev/null || echo unknown)"
    make -C scripts/vphoned GIT_HASH="$GIT_HASH" >/tmp/iphoneem-vphoned.log 2>&1 \
      || echo "  warning: vphoned build failed (see /tmp/iphoneem-vphoned.log)"
    if [[ -f scripts/vphoned/vphoned ]]; then
      cp -f scripts/vphoned/vphoned "$BUILD_DIR/vphoned.signed"
      ldid -Sscripts/vphoned/entitlements.plist -M -Kscripts/vphoned/signcert.p12 "$BUILD_DIR/vphoned.signed" || true
    fi
  else
    echo "  warning: ldid not installed (brew install ldid-procursus) - guest features stay off"
  fi
fi

echo "=== [5/6] bundle $APP ==="
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp -f .build/release/vphone-cli "$APP/Contents/MacOS/iPhoneEM"
cp -f "$HERE/app/EMInfo.plist" "$APP/Contents/Info.plist"
cp -f "$HERE/tools/EMAppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"
cp -f scripts/vphoned/signcert.p12 "$APP/Contents/Resources/signcert.p12"
if command -v ldid >/dev/null 2>&1; then
  cp -f "$(command -v ldid)" "$APP/Contents/MacOS/ldid"
  codesign --force --sign - "$APP/Contents/MacOS/ldid"
fi

RES="$APP/Contents/Resources"
mkdir -p "$RES/scripts" "$RES/tools" "$RES/.tools/bin"
rsync -a --exclude 'setup_machine.sh' --exclude 'repos' --exclude '__pycache__' --exclude '.git' \
      --exclude '.build' --exclude 'vphoned/vendor' scripts/ "$RES/scripts/"
cp -f tools/apfs_snap_rename.py "$RES/tools/apfs_snap_rename.py"
for tool in trustcache insert_dylib; do
  if [[ -x ".tools/bin/$tool" ]]; then
    cp -f ".tools/bin/$tool" "$RES/.tools/bin/$tool"
  else
    echo "  warning: .tools/bin/$tool missing - run ./scripts/setup_tools.sh in the engine for the create pipeline"
  fi
done
[[ -f "$BUILD_DIR/vphoned.signed" ]] && cp -f "$BUILD_DIR/vphoned.signed" "$RES/vphoned.signed"
cp -f requirements.txt "$RES/requirements.txt"
cp -f debs.list "$RES/debs.list"
cp -f README.md "$RES/README.md"
cp -f scripts/vphone-amfidont "$RES/vphone-amfidont"
chmod +x "$RES/vphone-amfidont"

echo "=== [6/6] sign + install ==="
codesign --force --sign - --entitlements "$ENTITLEMENTS" "$APP/Contents/MacOS/iPhoneEM"
codesign --force --sign - "$APP" 2>/dev/null || true
if [[ "$INSTALL" == "1" ]]; then
  rm -rf "/Applications/iPhoneEM.app"
  ditto "$APP" "/Applications/iPhoneEM.app"
  echo "  installed /Applications/iPhoneEM.app"
fi
echo ""
echo "done -> $APP"
