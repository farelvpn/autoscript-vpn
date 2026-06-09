#!/usr/bin/env bash
# ========================================================
# Project: Autoscript VPN by risqinf
# Description: Auto-expire VLESS accounts (DB-driven)
# License: Apache License 2.0 (see LICENSE file)
# Repository: https://github.com/risqinf/autoscript
# ========================================================
. /usr/local/sbin/lib/account.sh

db_init
now=$(date +%s)
deleted=0

while IFS='|' read -r user; do
  [[ -z "$user" ]] && continue
  if acc_xray_suspend "vless" "$user" "expired"; then
    db_set_status "vless" "$user" "expired"
    db_audit "expire" "vless" "$user" ""
    tg_send "<b>[ VLESS EXPIRED ]</b>%0AUsername: <code>${user}</code>"
    deleted=$((deleted+1))
  fi
done < <(db_query "SELECT username FROM accounts
                   WHERE protocol='vless' AND status='active' AND expired_at < ${now};")

[[ $deleted -gt 0 ]] && systemctl restart xray.service >/dev/null 2>&1
exit 0
