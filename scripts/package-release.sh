#!/bin/zsh
set -euo pipefail
cd "${0:A:h:h}"
zsh scripts/build-app.sh
app_dir="$PWD/dist/Disinformation Labs.app"
version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$app_dir/Contents/Info.plist")"
architecture="$(uname -m)"
release_dir="$PWD/dist/releases/v$version"
mkdir -p "$release_dir"
archive="Disinformation-Labs-v${version}-macOS-${architecture}.zip"
"$app_dir/Contents/MacOS/DisinformationWorkshop" --smoke-test
/usr/bin/codesign --verify --deep --strict "$app_dir"
/usr/bin/ditto -c -k --sequesterRsrc --keepParent "$app_dir" "$release_dir/$archive"
cd "$release_dir"
/usr/bin/shasum -a 256 "$archive" > SHA256SUMS.txt
print "Release files: $release_dir"
