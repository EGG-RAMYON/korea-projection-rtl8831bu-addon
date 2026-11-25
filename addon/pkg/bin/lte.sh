#!/system/bin/sh
# SPDX-License-Identifier: AGPL-3.0-or-later
# A dedicated FORWARD chain keeps DHCP and projection traffic to the head unit local.
KP_AX_CHAIN=KP_AX8831
kp_ax_fwd_top() {
  "$1" -S FORWARD 2>/dev/null | "$BB" awk -v chain="$KP_AX_CHAIN" '
    $1 == "-A" && $2 == "FORWARD" {
      n++
      if (n == 1 && $0 == "-A FORWARD -i wlan0 -j " chain) first=1
      if (n == 2 && $0 == "-A FORWARD -o wlan0 -j " chain) second=1
    }
    END { exit !(first && second) }'
}
kp_ax_fwd_del() {
  local tool="$1" dir
  [ -x "$tool" ] || return 0
  for dir in -i -o; do
    while "$tool" -D FORWARD "$dir" wlan0 -j "$KP_AX_CHAIN" 2>/dev/null; do :; done
  done
  if "$tool" -S "$KP_AX_CHAIN" >/dev/null 2>&1; then
    "$tool" -F "$KP_AX_CHAIN" && "$tool" -X "$KP_AX_CHAIN"
  fi
}
kp_ax_fwd_one() {
  local tool="$1"
  [ -x "$tool" ] || return 1
  if ! "$tool" -S "$KP_AX_CHAIN" >/dev/null 2>&1; then
    "$tool" -N "$KP_AX_CHAIN" || return 1
    if ! "$tool" -A "$KP_AX_CHAIN" -j DROP; then
      "$tool" -X "$KP_AX_CHAIN"
      return 1
    fi
  fi
  [ "$("$tool" -S "$KP_AX_CHAIN" 2>/dev/null)" = "-N $KP_AX_CHAIN
-A $KP_AX_CHAIN -j DROP" ] || return 1
  if ! kp_ax_fwd_top "$tool"; then
    # Insert before any existing accept rules. Keep old jumps until the new pair
    # is installed so refreshing a live AP does not temporarily open forwarding.
    "$tool" -I FORWARD 1 -o wlan0 -j "$KP_AX_CHAIN" &&
      "$tool" -I FORWARD 1 -i wlan0 -j "$KP_AX_CHAIN" || return 1
  fi
  kp_ax_fwd_top "$tool"
}
kp_ax_no_forward() {
  kp_ax_fwd_one "${KP_AX_IPT:-/system/bin/iptables}" &&
    kp_ax_fwd_one "${KP_AX_IP6T:-/system/bin/ip6tables}"
}
kp_ax_clear_forward() {
  local failed=0
  kp_ax_fwd_del "${KP_AX_IPT:-/system/bin/iptables}" || failed=1
  kp_ax_fwd_del "${KP_AX_IP6T:-/system/bin/ip6tables}" || failed=1
  return "$failed"
}
