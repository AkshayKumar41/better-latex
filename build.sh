#!/bin/bash
# Builds dist/BetterLaTeX.app. No package manager, no network, no Xcode project.
set -euo pipefail
cd "$(dirname "$0")"

TARGET="arm64-apple-macos14.0"
APP="dist/BetterLaTeX.app"
SRC=(Sources/Transpile/*.swift Sources/App/*.swift)

case "${1:-app}" in
install)
  # build, then replace the copy in /Applications
  "$0" app
  rm -rf "/Applications/BetterLaTeX.app"
  cp -R "dist/BetterLaTeX.app" "/Applications/BetterLaTeX.app"
  echo "installed /Applications/BetterLaTeX.app"
  exit 0
  ;;
test)
  mkdir -p build
  swiftc -O -target "$TARGET" Sources/Transpile/*.swift tests/main.swift -o build/bltx-test
  exec ./build/bltx-test
  ;;
docs)
  mkdir -p build
  swiftc -O -target "$TARGET" Sources/Transpile/*.swift tools/GenerateReference/main.swift -o build/gendocs
  exec ./build/gendocs COMMANDS.md
  ;;
clean)
  rm -rf build dist
  echo "cleaned"
  exit 0
  ;;
esac

mkdir -p build

# 1. transpiler checks gate the build
swiftc -O -target "$TARGET" Sources/Transpile/*.swift tests/main.swift -o build/bltx-test
./build/bltx-test

# 2. app icon (cached)
if [ ! -f build/AppIcon.icns ]; then
  swiftc -O -target "$TARGET" tools/MakeIcon/main.swift -o build/makeicon
  ./build/makeicon build/icon.iconset >/dev/null
  iconutil -c icns build/icon.iconset -o build/AppIcon.icns
fi

# 3. the binary: whole-module optimization, one executable
swiftc -O -whole-module-optimization -parse-as-library -target "$TARGET" \
  "${SRC[@]}" -o build/BetterLaTeX

# 4. bundle
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp build/BetterLaTeX "$APP/Contents/MacOS/BetterLaTeX"
cp build/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
cp Info.plist "$APP/Contents/Info.plist"
cp Resources/preview.html "$APP/Contents/Resources/preview.html"
cp -R Resources/katex "$APP/Contents/Resources/katex"
cp -R Resources/sample "$APP/Contents/Resources/sample"
printf 'APPL????' > "$APP/Contents/PkgInfo"

# 5. ad-hoc signature so Gatekeeper lets a locally built app run
codesign --force --sign - --timestamp=none "$APP" >/dev/null 2>&1 || true

echo "built $APP  ($(du -sh "$APP" | cut -f1))"
