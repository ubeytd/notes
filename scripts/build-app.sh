#!/bin/zsh
set -euo pipefail
cd "${0:A:h}/.."

swift build -c release
swift build -c release --triple x86_64-apple-macosx13.0 --scratch-path .build/x86_64
arm_bin=$(swift build -c release --show-bin-path)
intel_bin=$(swift build -c release --triple x86_64-apple-macosx13.0 --scratch-path .build/x86_64 --show-bin-path)

app="dist/Notes.app"
rm -rf "$app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
lipo -create "$arm_bin/Notes" "$intel_bin/Notes" -output "$app/Contents/MacOS/Notes"
cp -R "$arm_bin/Notes_Notes.bundle" "$app/Contents/Resources/"
cp mcp/notes_server.py "$app/Contents/Resources/notes_mcp_server.py"
cp packaging/Info.plist "$app/Contents/Info.plist"

iconset="dist/.Notes.iconset"
rm -rf "$iconset"
mkdir -p "$iconset"
swift scripts/make-icon.swift dist/Notes-icon.png
for size in 16 32 128 256 512; do
    sips -s format png -z "$size" "$size" dist/Notes-icon.png --out "$iconset/icon_${size}x${size}.png" >/dev/null
    double=$((size * 2))
    sips -s format png -z "$double" "$double" dist/Notes-icon.png --out "$iconset/icon_${size}x${size}@2x.png" >/dev/null
done
iconutil -c icns "$iconset" -o "$app/Contents/Resources/Notes.icns"
rm -rf "$iconset"

if [[ -n "${NOTES_SIGN_IDENTITY:-}" ]]; then
    codesign --force --deep --options runtime --timestamp --sign "$NOTES_SIGN_IDENTITY" "$app"
else
    codesign --force --deep --sign - "$app"
fi
codesign --verify --deep --strict --verbose=2 "$app"
plutil -lint "$app/Contents/Info.plist"
echo "Built universal $app"
