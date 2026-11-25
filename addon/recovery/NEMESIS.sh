#!/system/bin/sh
# SPDX-License-Identifier: AGPL-3.0-or-later
# Requires an on-screen confirmation.
export PATH=/sbin:/vendor/bin:/system/sbin:/system/bin:/system/xbin
export LD_LIBRARY_PATH=/vendor/lib:/system/lib
AX_HOME=/data/nemesis/apps/korea.projection.rtl8831bu
CLI=/system/xbin/nemesis
[ -x "$CLI" ] || exit 1
if [ -d "$AX_HOME" ]; then
  "$CLI" uninstall korea.projection.rtl8831bu
  exit $?
fi
echo "AX add-on absent. If KP reports a mismatch, reinstall the verified official KP ZIP."
exit 0
