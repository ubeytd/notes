#!/bin/zsh
set -euo pipefail
cd "${0:A:h}/.."
if [[ -n "${NOTES_NOTARY_PROFILE:-}" && -z "${NOTES_SIGN_IDENTITY:-}" ]]; then
    echo "NOTES_SIGN_IDENTITY is required for notarization" >&2
    exit 1
fi
./scripts/build-app.sh

version=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' dist/Notes.app/Contents/Info.plist)
image="dist/Notes-${version}-universal.dmg"
staging=$(mktemp -d /tmp/NotesInstaller.XXXXXX)
trap 'rm -rf "$staging"' EXIT
cp -R dist/Notes.app "$staging/Notes.app"
ln -s /Applications "$staging/Applications"
rm -f "$image"
diskutil image create from --volumeName "Notes ${version}" --format UDZO "$staging" "$image" >/dev/null
if [[ -n "${NOTES_NOTARY_PROFILE:-}" ]]; then
    xcrun notarytool submit "$image" --keychain-profile "$NOTES_NOTARY_PROFILE" --wait
    xcrun stapler staple "$image"
fi
(cd dist && shasum -a 256 "${image:t}") > "$image.sha256"
echo "Built $image"
