#!/system/bin/sh
# SPDX-License-Identifier: AGPL-3.0-or-later
. /data/nemesis/apps/korea.projection.rtl8831bu/bin/transaction.sh
echo "Korea Projection RTL8831BU Add-on (Unofficial)"
if ax_stock; then
  echo "공식 KP 파일 확인. 애드온 패치 비활성."
elif [ "$(ax_hash "$KP/$HS")" = "$(ax_hash "$AX/bin/hotspot.patched")" ] &&
     [ "$(ax_hash "$KP/$MD")" = "$(ax_hash "$AX/bin/manifest.patched")" ] && ax_payload; then
  echo "애드온 패치 적용. KP 상태 화면에서 USB Wi-Fi 동글을 켠 뒤 재부팅."
else
  echo "파일 상태 확인 필요. 복구 가이드 참조."
fi
