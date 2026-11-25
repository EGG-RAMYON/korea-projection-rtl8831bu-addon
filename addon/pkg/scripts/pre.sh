#!/system/bin/sh
# SPDX-License-Identifier: AGPL-3.0-or-later
export PATH=/sbin:/vendor/bin:/system/sbin:/system/bin:/system/xbin
AX_HERE=$(pwd)
KP_AX_APP=$AX_HERE
. "$AX_HERE/bin/transaction.sh"
ax_check_install
