#!/system/bin/sh
# SPDX-License-Identifier: AGPL-3.0-or-later
# Runs from the USB root under NEMESIS after confirmation.
export PATH=/sbin:/vendor/bin:/system/sbin:/system/bin:/system/xbin
umask 077
USB=$(pwd -P) || exit 1
NEMESIS=/data/nemesis
ADDON=korea.projection.rtl8831bu
KP=$NEMESIS/apps/korea.projection
AX=$NEMESIS/apps/$ADDON
BB=
for candidate in "$KP/bin/busybox" /system/bin/busybox; do
  if [ -x "$candidate" ] && "$candidate" true 2>/dev/null; then BB=$candidate; break; fi
done
tool() {
  if [ -n "$BB" ]; then "$BB" "$@"; else command "$@"; fi
}
version_of() {
  if [ -r "$1/NEMESIS.data" ]; then
    tool grep '^package-version=' "$1/NEMESIS.data"
  else
    echo 'package not present or unreadable'
  fi
}

collect() {
  echo 'Korea Projection RTL8831BU add-on installation diagnostic'
  tool date
  echo '=== Target checks ==='
  for key in ro.build.product ro.board.platform ro.build.version.release ro.product.cpu.abi; do
    echo "$key=$(getprop "$key")"
  done
  echo "kernel=$(tool uname -r)"
  echo "machine=$(tool uname -m)"
  echo "busybox=${BB:-unavailable}"
  echo '=== Installed packages ==='
  echo 'Official KP'
  version_of "$KP"
  echo 'RTL8831BU add-on'
  version_of "$AX"
  if [ -f "$NEMESIS/backup/$ADDON/ready" ]; then echo 'Add-on backup marker: present'; fi

  echo '=== Official KP v1.8.0 file check ==='
  if [ -z "$BB" ] || [ ! -r "$USB/KP180-stock.sha256" ] || [ ! -d "$KP" ]; then
    echo 'SHA-256 comparison unavailable'
  else
    checked=0
    failed=0
    while read -r expected name; do
      case "$name" in ''|/*|*..*|*[!a-zA-Z0-9._/-]*) continue ;; esac
      checked=$((checked + 1))
      if actual=$("$BB" sha256sum < "$KP/$name" 2>/dev/null); then
        if [ "${actual%% *}" = "$expected" ]; then continue; fi
        echo "Mismatch: $name"
      else
        echo "Missing or unreadable: $name"
      fi
      failed=$((failed + 1))
    done < "$USB/KP180-stock.sha256"
    echo "Checked=$checked Differences=$failed"
    echo 'The two patched KP files will differ when an add-on is active.'
  fi

  if [ -r "$AX/install-status.txt" ]; then
    echo '=== Add-on installation stage ==='
    tool tail -n 8 "$AX/install-status.txt"
  fi

  echo '=== Latest add-on queue job ==='
  latest=
  for record in "$NEMESIS"/queue/[0-9]*.job; do
    [ -f "$record" ] || continue
    tool grep -Fxq "id=$ADDON" "$record" && latest=$record
  done
  if [ -n "$latest" ]; then
    echo "Job: ${latest##*/}"
    tool grep -E '^(action|id|state|rc|unclean)=' "$latest"
    job_output=${latest%.job}.out
    if [ -r "$job_output" ]; then
      echo '=== Add-on installer output ==='
      tool tail -n 60 "$job_output"
    fi
  else
    echo 'No matching retained queue job.'
  fi

  echo '=== Legacy USB handler output ==='
  handler=$NEMESIS/logs/usb-handler/usb-handler.log
  if [ -r "$handler" ]; then
    tool tail -n 500 "$handler" |
      tool grep -Ei 'AX_ADDON_INSTALL|rtl8831bu|Hash mismatch|hotspot\.sh|kp-files\.md5|permission denied|not found|boot_id|busybox|postinstall|preinstall|unzip failed' |
      tool tail -n 45
  else
    echo 'USB handler log unavailable.'
  fi

  echo '=== NEMESIS log (relevant lines) ==='
  found=0
  for log in "$NEMESIS/nemesis.log" /data/local/tmp/nemesis/nemesis.log; do
    [ -r "$log" ] || continue
    found=1
    tool tail -n 450 "$log" |
      tool grep -E 'rtl8831bu|preinstall failed|postinstall failed|Hash mismatch|unzip failed' |
      tool tail -n 45
  done
  [ "$found" = 1 ] || echo 'NEMESIS log unavailable.'
}

target=$USB/KP_AX_INSTALL_DIAG.txt
temp=$USB/KP_AX_INSTALL_DIAG.$$.tmp
(set -C; collect > "$temp" 2>&1) || {
  echo 'Could not finish writing the diagnostic report to USB.'
  exit 1
}
tool mv -f "$temp" "$target" || exit 1
tool sync
echo 'Diagnostic saved to USB: KP_AX_INSTALL_DIAG.txt'
