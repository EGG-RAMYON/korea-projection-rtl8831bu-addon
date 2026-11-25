#!/system/bin/sh
# SPDX-License-Identifier: AGPL-3.0-or-later
KP_ID=korea.projection
AX_ID=korea.projection.rtl8831bu
KP=${KP_AX_BASE:-/data/nemesis/apps/$KP_ID}
AX=${KP_AX_APP:-/data/nemesis/apps/$AX_ID}
AX_BACKUP=${KP_AX_BACKUP:-/data/nemesis/backup/$AX_ID}
AX_NEMESIS=${KP_AX_NEMESIS:-/system/xbin/nemesis}
AX_MODULES=${KP_AX_MODULES:-/proc/modules}
AX_BOOT_ID=${KP_AX_BOOT_ID:-/proc/sys/kernel/random/boot_id}
AX_PROC=${KP_AX_PROC:-/proc}
KP_BACKUP=${KP_AX_KP_BACKUP:-/data/nemesis/backup/$KP_ID}
KP_WORK=${KP_AX_KP_WORK:-/data/local/tmp/$KP_ID}
BB=$KP/bin/busybox
HS=svc/hotspot.sh
MD=bin/kp-files.md5
AX_INSTALL_STATUS=$AX/install-status.txt

ax_install_status() {
  echo "AX_ADDON_INSTALL: $*"
  (umask 077; echo "$*" > "$AX_INSTALL_STATUS")
}

ax_check_install() {
  ax_target || { echo 'target-check: unsupported firmware, architecture or kernel'; return 1; }
  ax_stock || { echo 'stock-check: official KP file validation failed'; return 1; }
  ax_payload || { echo 'payload-check: add-on file validation failed'; return 1; }
  [ -x "$AX_NEMESIS" ] || { echo 'nemesis-check: service CLI unavailable'; return 1; }
}


ax_hash() {
  local sum
  [ -f "$1" ] && [ ! -L "$1" ] || return 1
  sum=$("$BB" sha256sum < "$1") || return 1
  echo "${sum%% *}"
}

ax_verify_list() {
  local list="$1" base="$2" sha name actual
  [ -s "$list" ] || return 1
  while read -r sha name; do
    [ -n "$sha" ] && [ -n "$name" ] || return 1
    case "$name" in /*|*..*|*[!a-zA-Z0-9._/-]*) return 1 ;; esac
    actual=$(ax_hash "$base/$name") || return 1
    [ "$actual" = "$sha" ] || { echo "Hash mismatch: $name"; return 1; }
  done < "$list"
}

ax_stock() { ax_verify_list "$AX/bin/stock.sha256" "$KP"; }
ax_payload() { ax_verify_list "$AX/bin/payload.sha256" "$AX/bin"; }

ax_target() {
  [ "$(getprop ro.build.version.release)" = 4.4.2 ] &&
  [ "$(getprop ro.board.platform)" = tcc803x ] &&
  [ "$("$BB" uname -r)" = 3.18.24-tcc ] &&
  [ "$("$BB" uname -m)" = armv7l ] || return 1
  case "$(getprop ro.build.product)" in
    NX4HEV.KOR.0000.V039.001.260902|NX4HEV.KOR.S5W_M.V039.001.260902) return 0 ;;
  esac
  return 1
}

# Verify the exact shell invocation before signalling. A pathname mentioned
# later in another program's arguments is not a running copy of the service.
ax_kp_script() {
  local pid="$1" proc state argv
  case "$pid" in ''|*[!0-9]*) return 1 ;; esac
  [ "$pid" -gt 1 ] || return 1
  proc=$AX_PROC/$pid
  [ -d "$proc" ] || return 1
  state=$("$BB" awk '/^State:/ { s=$2 } /^Uid:/ { u=$2; e=$3 }
    END { if (u==0 && e==0 && s!="Z" && s!="X") print s }' "$proc/status" 2>/dev/null) || { [ ! -d "$proc" ] && return 1; return 2; }
  [ -n "$state" ] || return 1
  argv=$("$BB" tr '\000' '\n' < "$proc/cmdline" 2>/dev/null) || { [ ! -d "$proc" ] && return 1; return 2; }
  echo "$argv" | "$BB" awk -v script="$KP/$HS" '
      NR==1 { sub(/^.*\//, ""); shell=($0=="sh" || $0=="mksh") }
      NR==2 { exact=(shell && $0==script); exit }
      END { exit !exact }'
}

ax_kp_processes() {
  local output candidates pid
  output=$("$BB" ps -o pid,args) || return 1
  candidates=$(echo "$output" | "$BB" awk -v p="$KP/$HS" '$3==p { print $1 }') || return 1
  for pid in $candidates; do
    if ax_kp_script "$pid"; then
      echo "$pid"
    elif [ "$?" -eq 2 ]; then
      return 1
    fi
  done
  return 0
}

ax_stop() {
  "$AX_NEMESIS" service stop "$KP_ID/ap" || {
    echo 'service-stop: NEMESIS stop command failed'
    return 1
  }
  local i=0 remaining pid notified=' '
  while [ "$i" -lt 8 ]; do
    remaining=$(ax_kp_processes) || { echo 'service-stop: process inspection failed'; return 1; }
    [ -z "$remaining" ] && return 0
    for pid in $remaining; do
      case "$notified" in *" $pid "*) continue ;; esac
      if ax_kp_script "$pid"; then
        kill -TERM "$pid" 2>/dev/null || :
        notified="$notified$pid "
      fi
    done
    sleep 1
    i=$((i+1))
  done
  remaining=$(ax_kp_processes) || { echo 'service-stop: final process inspection failed'; return 1; }
  [ -z "$remaining" ] && return 0
  echo "service-stop: KP shell still running after TERM, PID(s): $remaining"
  return 1
}

ax_restart() {
  if "$BB" grep -q '^8851bu ' "$AX_MODULES" 2>/dev/null; then
    echo "8851bu is loaded. Reboot with the AX dongle unplugged to resume official KP."
    return 0
  fi
  "$AX_NEMESIS" service start "$KP_ID/ap"
}

ax_exchange() {
  local input="$1" target="$KP/$2" temp="$KP/$2.kp-ax-tmp"
  # Use the existing target as metadata template. Atomic rename is confined
  # to the original directory. Never follow symlinks or reuse unknown temp files.
  [ -f "$target" ] && [ ! -L "$target" ] && [ ! -e "$temp" ] && [ ! -L "$temp" ] || return 1
  "$BB" cp -p "$target" "$temp" &&
    "$BB" cat "$input" > "$temp" &&
    "$BB" mv -f "$temp" "$target"
  local status=$?
  "$BB" rm -f "$temp"
  return "$status"
}

ax_known() {
  local path="$1" payload="$2" current original patched
  current=$(ax_hash "$KP/$path") || return 1
  original=$("$BB" awk -v n="$path" '$2 == n { print $1 }' "$AX/bin/stock.sha256")
  [ -n "$original" ] && [ "$(ax_hash "$AX_BACKUP/$path")" = "$original" ] || return 1
  patched=$("$BB" awk -v n="$payload" '$2 == n { print $1 }' "$AX/bin/payload.sha256")
  [ "$current" = "$original" ] || [ "$current" = "$patched" ]
}

ax_restore() {
  if ax_stock; then
    if [ -f "$AX_BACKUP/ready" ]; then
      "$BB" rm -f "$KP/$HS.kp-ax-tmp" "$KP/$MD.kp-ax-tmp"
    fi
    return 0
  fi
  # Only restore the pairs the current add-on actually installed.
  [ -f "$AX_BACKUP/ready" ] &&
    ax_known "$HS" hotspot.patched && ax_known "$MD" manifest.patched || return 1
  "$BB" rm -f "$KP/$HS.kp-ax-tmp" "$KP/$MD.kp-ax-tmp" &&
    ax_exchange "$AX_BACKUP/$HS" "$HS" &&
    ax_exchange "$AX_BACKUP/$MD" "$MD" && "$BB" sync && ax_stock
}

ax_install() {
  local boot stage details
  ax_install_status 'checking'
  if ! details=$(ax_check_install 2>&1); then ax_install_status "failed $details"; return 1; fi
  if [ -e "$KP/$HS.kp-ax-tmp" ] || [ -L "$KP/$HS.kp-ax-tmp" ] ||
     [ -e "$KP/$MD.kp-ax-tmp" ] || [ -L "$KP/$MD.kp-ax-tmp" ]; then
    ax_install_status 'failed stale exchange file'
    return 1
  fi
  if ! { read -r boot < "$AX_BOOT_ID" && [ -n "$boot" ]; }; then
    ax_install_status 'failed boot-id unavailable'
    return 1
  fi
  ax_install_status 'stopping KP'
  if ! details=$(ax_stop 2>&1); then
    ax_install_status "failed $details"
    ax_restart
    return 1
  fi
  stage=backup
  if ! {
    (umask 077; "$BB" mkdir -p "$AX_BACKUP/svc" "$AX_BACKUP/bin") &&
    "$BB" cp -p "$KP/$HS" "$AX_BACKUP/$HS" &&
    "$BB" cp -p "$KP/$MD" "$AX_BACKUP/$MD" &&
    (umask 077; "$BB" printf '%s\n' "$boot" > "$AX_BACKUP/ready") &&
    "$BB" sync &&
    { stage=manifest-swap; ax_exchange "$AX/bin/manifest.patched" "$MD"; } &&
    { stage=service-script-swap; ax_exchange "$AX/bin/hotspot.patched" "$HS"; } &&
    { stage=verify-swapped-files
      [ "$(ax_hash "$KP/$HS")" = "$(ax_hash "$AX/bin/hotspot.patched")" ] &&
        [ "$(ax_hash "$KP/$MD")" = "$(ax_hash "$AX/bin/manifest.patched")" ] &&
        "$BB" sync; }
  }; then
    if ax_restore && ax_restart; then
      "$BB" rm -rf "$AX_BACKUP"
      ax_install_status "failed stage=$stage stock-restored"
    else
      ax_install_status "failed stage=$stage recovery-check-required"
    fi
    return 1
  fi
  ax_install_status 'applied reboot-required'
  echo "AX add-on installed. Remove the USB installer and reboot with the AX dongle connected."
}

ax_remove() {
  if [ ! -e "$AX_BACKUP/ready" ] && ax_stock; then return 0; fi
  ax_stop || return 1
  ax_restore || { echo "Unknown KP files or incomplete recovery. See recovery guide."; return 1; }
  # Keep the forwarding block until reboot if the old interface still exists.
  if ! "$BB" grep -q '^8851bu ' "$AX_MODULES" 2>/dev/null; then
    . "$AX/bin/lte.sh"
    kp_ax_clear_forward || return 1
  fi
  # Restore temporary AOA and USB recovery changes using KP's own recovery logic.
  if [ -d "$KP_BACKUP" ] || [ -d "$KP_WORK" ]; then
    (
      APP=$KP BK=$KP_BACKUP W=$KP_WORK HOTSPOT_LIB=1
      . "$KP/$HS"
      dg_guard_release
      [ ! -f "$DG_LADF" ] || dg_ladder_restore stop
    )
  fi
  "$BB" rm -f "$KP_BACKUP/dongle.driver" "$KP_BACKUP/dongle.driver.tmp" "$KP_BACKUP/dongle.cdrom" "$KP_BACKUP/dongle.cdrom.tmp" "$KP_WORK/ax-lte.ok" "$KP_WORK/ax-lte.fail"
  ax_restart && "$BB" rm -rf "$AX_BACKUP"
}
