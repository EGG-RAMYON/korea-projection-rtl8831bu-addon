#!/usr/bin/env bash
set -euo pipefail
stock=$1 payload=$2
testdir=$(mktemp -d)
trap 'rm -rf "$testdir"' EXIT
export KP_AX_BASE=$testdir/kp KP_AX_APP=$testdir/ax KP_AX_BACKUP=$testdir/backup
export KP_AX_KP_BACKUP=$testdir/kp-state KP_AX_KP_WORK=$testdir/kp-work KP_AX_MODULES=$testdir/modules
export KP_AX_NEMESIS=$testdir/nemesis
cp -a "$stock" "$KP_AX_BASE"
cp -a "$payload" "$KP_AX_APP"
: > "$KP_AX_MODULES"
cat > "$KP_AX_NEMESIS" <<'SH'
#!/bin/sh
echo "$*" >> "$KP_AX_APP/calls"
SH
chmod +x "$KP_AX_NEMESIS"
# On a build host the release's ARM BusyBox cannot execute.
. "$KP_AX_APP/bin/transaction.sh"
BB=$(command -v busybox)
ax_target() { return 0; }
# Exercise a live leftover shell, other arguments and a zombie, with no real signals.
(
  real_bb=$BB
  AX_PROC=$testdir/proc
  mkdir -p "$AX_PROC"/{21,22,23,24}
  printf 'State: S\nUid: 0 0 0 0\n' > "$AX_PROC/21/status"
  cp "$AX_PROC/21/status" "$AX_PROC/22/status"
  cp "$AX_PROC/21/status" "$AX_PROC/24/status"
  printf 'State: Z\nUid: 0 0 0 0\n' > "$AX_PROC/23/status"
  printf 'sh\0%s\0' "$KP/$HS" > "$AX_PROC/21/cmdline"
  printf 'sh\0-c\0%s\0' "$KP/$HS" > "$AX_PROC/22/cmdline"
  printf 'sh\0%s\0' "$KP/$HS" > "$AX_PROC/23/cmdline"
  printf 'unrelated\0%s\0' "$KP/$HS" > "$AX_PROC/24/cmdline"
  bb_fixture() {
    if [ "$1" = ps ]; then
      for pid in 21 22 23 24; do
        [ ! -d "$AX_PROC/$pid" ] || printf '%s sh %s\n' "$pid" "$KP/$HS"
      done
    else "$real_bb" "$@"; fi
  }
  kill() {
    [ "$1:$2" = '-TERM:21' ] || return 1
    rm -r "$AX_PROC/21"
  }
  sleep() { :; }
  BB=bb_fixture
  [ "$(ax_kp_processes)" = 21 ]
  ax_stop
  [ ! -d "$AX_PROC/21" ]
  [ -d "$AX_PROC/22" ] && [ -d "$AX_PROC/23" ] && [ -d "$AX_PROC/24" ]
)
rm -f "$KP_AX_APP/calls"
echo 'PASS: leftover KP shell receives TERM, unrelated and zombie processes are excluded'
ax_stock
ax_payload
printf 'change' >> "$KP_AX_BASE/bin/kp-files.md5"
if ax_install; then exit 1; fi
[ ! -f "$KP_AX_APP/calls" ]
cp "$stock/bin/kp-files.md5" "$KP_AX_BASE/bin/kp-files.md5"
(
  ax_stop() { echo 'service-stop: simulated failure'; return 1; }
  if ax_install; then exit 1; fi
  grep -qx 'failed service-stop: simulated failure' "$AX_INSTALL_STATUS"
  ax_stock
)
rm -f "$KP_AX_APP/calls"
ax_install
grep -qx 'applied reboot-required' "$AX_INSTALL_STATUS"
cmp "$KP_AX_BASE/svc/hotspot.sh" "$KP_AX_APP/bin/hotspot.patched"
cmp "$KP_AX_BASE/bin/kp-files.md5" "$KP_AX_APP/bin/manifest.patched"
[ "$(stat -c %a "$KP_AX_BASE/svc/hotspot.sh")" = "$(stat -c %a "$stock/svc/hotspot.sh")" ]
[ "$(wc -l < "$KP_AX_APP/calls")" = 1 ]
(
  export HOTSPOT_LIB=1 APP="$KP_AX_BASE" BB="$BB" BB_OWN="$BB"
  mkdir -p "$testdir/sys/1-1" "$testdir/sys/1-1:1.0" "$testdir/sys/drivers/rtl8851bu"
  export USB_SYS="$testdir/sys" DG_OUIT="$testdir/oui" DG_HT="$testdir/id"
  sed '/^export PATH=/d' "$KP_AX_BASE/svc/hotspot.sh" > "$testdir/runtime"
  set +u +e
  . "$testdir/runtime"
  dg_ax_target() { return 0; }
  getprop() { echo tcc803x; }
  kp_verify || exit 1
  echo 0bda > "$USB_SYS/1-1/idVendor"
  echo b831 > "$USB_SYS/1-1/idProduct"
  dg_usb
  [ "$DG_USB $DG_USBID" = 'ok 0bda:b831' ] || exit 1
  dg_pick && [ "$DG_MOD $DG_G" = '8851bu tcc803x-a' ] || exit 1
  ln -s "$USB_SYS/drivers/rtl8851bu" "$USB_SYS/1-1:1.0/driver"
  dg_seen || exit 1
  DG_MOD=88x2bu
  if dg_seen; then exit 1; fi
  dg_ax_target() { return 1; }
  if dg_idok 0bda:b831; then exit 1; fi
  dg_ax_target() { return 0; }
  [ "$(dg_driver_for_id 2357:012d)" = 88x2bu ] || exit 1
  [ "$(dg_driver_for_id 0bda:b851)" = 8851bu ] || exit 1
  DG_MOD=8851bu DG_RUN=1 DG_ST=ok S2=test-connectivity S4=test-passphrase CONF="$testdir/hostapd.conf"
  write_conf 2>/dev/null
  grep -qx 'ssid=test-connectivity' "$CONF" && grep -qx 'channel=36' "$CONF" &&
    grep -qx 'country_code=KR' "$CONF" && ! grep -q '^ht_capab=' "$CONF" || exit 1
  DG_MOD=88x2bu
  write_conf 2>/dev/null
  grep -qx 'channel=149' "$CONF" && grep -q '^ht_capab=' "$CONF" || exit 1
  echo tampered >> "$KP_AX_BASE/svc/hotspot.sh"
  if kp_verify; then exit 1; fi
)
if ax_remove; then exit 1; fi
cp "$payload/bin/hotspot.patched" "$KP_AX_BASE/svc/hotspot.sh"
echo '8851bu 1 0 - Live 0' > "$KP_AX_MODULES"
ax_remove
ax_stock
[ ! -e "$KP_AX_BACKUP" ]
[ ! -e "$KP_AX_BASE/svc/hotspot.sh.kp-ax-tmp" ]
! grep -q 'service start' "$KP_AX_APP/calls"
: > "$KP_AX_MODULES"
ax_install
# Simulate an interruption after replacing only the manifest.
cp "$stock/svc/hotspot.sh" "$KP_AX_BASE/svc/hotspot.sh"
ax_remove
ax_stock
grep -q 'service start korea.projection/ap' "$KP_AX_APP/calls"
# Simulate a failed second rename and the normal in-hook recovery.
(
  eval "$(declare -f ax_exchange | sed '1s/ax_exchange/real_exchange/')"
  ax_exchange() {
    if [ "$1" = "$AX/bin/hotspot.patched" ]; then return 1; fi
    real_exchange "$@"
  }
  if ax_install; then exit 1; fi
  grep -qx 'failed stage=service-script-swap stock-restored' "$AX_INSTALL_STATUS"
  ax_stock
)
echo 'PASS: stock SHA-256 gate, install, mode preservation, AX/AC binding and profile, tamper refusal, interrupted and failed exchange recovery, loaded-module uninstall'
