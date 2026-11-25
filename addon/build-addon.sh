#!/usr/bin/env bash
# SPDX-License-Identifier: AGPL-3.0-or-later
set -euo pipefail
export LC_ALL=C TZ=UTC
root=$(cd "$(dirname "$0")/.." && pwd)
out=$(realpath "$1")
mkdir -p "$2"
stage=$(mktemp -d "$(realpath "$2")/addon.XXXXXX")
trap 'rm -rf "$stage"' EXIT
mkdir -p "$stage"/{addon,usb/packages,recovery}
pkg=$stage/addon
cp -R "$root/addon/pkg/." "$pkg/"
cp "$out/8851bu.ko" "$out/kp-eject" "$pkg/bin/"
stock=${KP_STOCK:-$root/nemesis-pkg/korea.projection}
(cd "$stock" && sha256sum -c --quiet "$pkg/bin/stock.sha256")
patch --silent --output "$pkg/bin/hotspot.patched" "$stock/svc/hotspot.sh" "$root/addon/hotspot-v1.8.0.patch"
patched=$(md5sum < "$pkg/bin/hotspot.patched")
sed "s|^[a-f0-9]*  svc/hotspot.sh$|${patched%% *}  svc/hotspot.sh|" \
  "$pkg/bin/base-manifest.md5" > "$pkg/bin/manifest.patched"
rm "$pkg/bin/base-manifest.md5"
(cd "$pkg/bin" && sha256sum 8851bu.ko kp-eject lte.sh hotspot.patched manifest.patched transaction.sh stock.sha256 > payload.sha256)
find "$pkg" -type f -exec chmod 644 {} +
find "$pkg" -type d -exec chmod 755 {} +
find "$pkg" -name "*.sh" -print0 | xargs -0 -n1 mksh -n
mksh -n "$pkg/bin/hotspot.patched"
chmod 755 "$pkg"/scripts/*.sh "$pkg"/bin/{status.sh,kp-eject}
name=korea.projection.rtl8831bu-$(sed -n 's/^package-version=//p' "$pkg/NEMESIS.data")
cp "$root/addon/docs/README_KO.md" "$pkg/README_KO.md"
cp "$root/addon/docs/NOTICE.md" "$pkg/NOTICE.md"
chmod 644 "$pkg/README_KO.md" "$pkg/NOTICE.md"
printf '[nemesis]\ntype=install\npath=packages/%s.zip\n' "$name" > "$stage/usb/NEMESIS.data"
cp "$root/addon/docs/README_KO.md" "$stage/usb/README.txt"
cp "$root/addon/recovery/"* "$stage/recovery/"
zip_tree() {
  local dir=$1 output=$2
  (cd "$dir" && find . -type f -exec touch -t 202611251200 {} + &&
    find . -type f | sed 's|^./||' | sort | zip -X -q "$output" -@)
}
rm -f "$out/$name.zip" "$out/$name-usb.zip" "$out/$name-recovery-usb.zip"
zip_tree "$pkg" "$out/$name.zip"
cp "$out/$name.zip" "$stage/usb/packages/$name.zip"
zip_tree "$stage/usb" "$out/$name-usb.zip"
zip_tree "$stage/recovery" "$out/$name-recovery-usb.zip"
bash "$root/addon/tests/test-addon.sh" "$stock" "$pkg"
bash "$root/addon/tests/test-lte.sh" "$pkg/bin/lte.sh"
python3 "$root/addon/tests/test-package.py" "$out" "$name"
