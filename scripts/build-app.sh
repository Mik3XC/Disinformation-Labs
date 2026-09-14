#!/bin/zsh
set -euo pipefail
cd "${0:A:h:h}"
swift build -c release --product DisinformationWorkshop
binary_dir="$(swift build -c release --show-bin-path)"
final_app="$PWD/dist/Disinformation Labs.app"
mkdir -p "$PWD/dist"
package_dir="$(mktemp -d "$PWD/dist/.Workshop-package.XXXXXX")"
app_dir="$package_dir/Disinformation Labs.app"
mkdir -p "$app_dir/Contents/MacOS" "$app_dir/Contents/Resources"
cp "$binary_dir/DisinformationWorkshop" "$app_dir/Contents/MacOS/DisinformationWorkshop"
cp Resources/Info.plist "$app_dir/Contents/Info.plist"
cp Resources/Workshop.icns "$app_dir/Contents/Resources/Workshop.icns"
cp -R "$binary_dir/DisinformationWorkshop_WorkshopCore.bundle" "$app_dir/Contents/Resources/"
/usr/bin/codesign --force --sign - "$app_dir"
/usr/bin/codesign --verify --deep --strict "$app_dir"
# Preserve the running executable's inode and keep a rollback copy. No user data
# lives inside these generated bundles; news and notes stay in Application Support.
if [[ -d "$final_app" ]]; then mv "$final_app" "$package_dir/Previous.app"; fi
if ! mv "$app_dir" "$final_app"; then
    if [[ -d "$package_dir/Previous.app" ]]; then mv "$package_dir/Previous.app" "$final_app"; fi
    exit 1
fi
# Retain an earlier branded bundle outside the visible release directory.
legacy_app="$PWD/dist/Disinformation Workshop.app"
if [[ -d "$legacy_app" ]]; then mv "$legacy_app" "$package_dir/Legacy Workshop.app"; fi
print "Built: $final_app"
