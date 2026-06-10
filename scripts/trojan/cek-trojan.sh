#!/usr/bin/env bash
# ========================================================
# Project: Autoscript VPN by risqinf
# Description: Check active TROJAN logins + quota usage
# License: Apache License 2.0 (see LICENSE file)
# Repository: https://github.com/risqinf/autoscript
# ========================================================
. /usr/local/sbin/lib/account.sh

db_init
xray_cek_monitor trojan
ui_back
menu
