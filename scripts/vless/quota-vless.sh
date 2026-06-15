#!/usr/bin/env bash
# ========================================================
# Project: Autoscript VPN by risqinf
# Description: VLESS traffic accounting + quota enforcement loop
# License: Apache License 2.0 (see LICENSE file)
# Repository: https://github.com/risqinf/autoscript
# ========================================================
# Every cycle it reads each active user's xray uplink+downlink counters,
# accumulates them into accounts.used_bytes (DB), then suspends any user
# that exceeded a finite quota. Unlimited users are still accounted.
. /usr/local/sbin/lib/account.sh
db_init

while true; do
  sleep 30
  xray_account_proto vless
done
