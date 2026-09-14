#!/bin/zsh
set -euo pipefail
cd "${0:A:h:h}"
mkdir -p output/brand
icon_build_dir="$(mktemp -d "$PWD/output/brand/.render.XXXXXX")"
trap 'rm -rf "$icon_build_dir"' EXIT
swiftc -parse-as-library Sources/DisinformationWorkshop/Brand.swift scripts/render-icon.swift -o "$icon_build_dir/render-icon"
"$icon_build_dir/render-icon" "$PWD/output/brand/output.png"
mkdir -p "$icon_build_dir/Workshop.iconset"
for size in 16 32 128 256 512; do
    sips -z "$size" "$size" output/brand/output.png --out "$icon_build_dir/Workshop.iconset/icon_${size}x${size}.png" >/dev/null
    sips -z "$((size * 2))" "$((size * 2))" output/brand/output.png --out "$icon_build_dir/Workshop.iconset/icon_${size}x${size}@2x.png" >/dev/null
done
iconutil -c icns "$icon_build_dir/Workshop.iconset" -o Resources/Workshop.icns
