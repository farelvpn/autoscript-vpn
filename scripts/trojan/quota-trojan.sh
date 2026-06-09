#!/usr/bin/env bash
# ========================================================
# Project: Autoscript VPN by risqinf
# Description: TROJAN quota enforcement loop (DB-driven)
# License: Apache License 2.0 (see LICENSE file)
# Repository: https://github.com/risqinf/autoscript
# ========================================================
. /usr/local/sbin/lib/account.sh
db_init

API="127.0.0.1:10085"

while true; do
  sleep 30
  while IFS='|' read -r user quota used; do
    [[ -z "$user" ]] && continue
    [[ "$quota" -le 0 ]] && continue

    # Pull downlink counter from xray stats and accumulate into DB.
    dl=$(xray api stats --server="$API" -name "user>>>${user}>>>traffic>>>downlink" 2>/dev/null \
         | grep -w value | awk '{print $2}' | tr -d '"')
    if [[ "$dl" =~ ^[0-9]+$ ]] && [[ "$dl" -gt 0 ]]; then
      xray api stats --server="$API" -name "user>>>${user}>>>traffic>>>downlink" -reset >/dev/null 2>&1
      db_exec "UPDATE accounts SET used_bytes = used_bytes + ${dl}, updated_at=strftime('%s','now')
               WHERE protocol='trojan' AND username='$(sql_escape "$user")';"
      used=$(( used + dl ))
    fi

    if [[ "$used" -ge "$quota" ]]; then
      acc_xray_suspend "trojan" "$user" "quota"
      tg_send "<b>[ TROJAN QUOTA EXCEEDED ]</b>%0AUsername: <code>${user}</code>%0AStatus: suspended"
    fi
  done < <(db_query "SELECT username, quota_bytes, used_bytes FROM accounts
                     WHERE protocol='trojan' AND status='active';")
done
