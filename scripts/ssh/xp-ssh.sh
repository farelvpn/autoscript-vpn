#!/usr/bin/env bash
# ========================================================
# Project: Autoscript VPN by risqinf
# Description: Auto-expire SSH accounts (DB-driven)
# License: Apache License 2.0 (see LICENSE file)
# Repository: https://github.com/risqinf/autoscript
# ========================================================
. /usr/local/sbin/lib/account.sh

db_init
now=$(date +%s)
count=0

while IFS='|' read -r user; do
  [[ -z "$user" ]] && continue
  id "$user" &>/dev/null && userdel --force "$user" >/dev/null 2>&1
  db_set_status "ssh" "$user" "expired"
  db_audit "expire" "ssh" "$user" ""
  tg_send "<b>[ SSH EXPIRED ]</b>%0AUsername: <code>${user}</code>"
  count=$((count+1))
done < <(db_query "SELECT username FROM accounts
                   WHERE protocol='ssh' AND status='active' AND expired_at < ${now};")

[[ $count -gt 0 ]] && systemctl restart dropbear >/dev/null 2>&1
exit 0
