#!/usr/bin/env bash
# ========================================================
# Project: Autoscript VPN by risqinf
# Description: VMESS IP-limit enforcement loop (DB-driven, grace threshold)
# License: Apache License 2.0 (see LICENSE file)
# Repository: https://github.com/risqinf/autoscript
# ========================================================
. /usr/local/sbin/lib/account.sh
db_init

LOG="/var/log/xray/access.log"
VIOLATION_THRESHOLD=3
declare -A strikes

while true; do
  while IFS='|' read -r user limit; do
    [[ -z "$user" ]] && continue
    [[ "$limit" -le 0 ]] && continue

    # Unique /24 networks in recent accepted connections (NAT tolerant).
    nets=$(grep -w "email: $user" "$LOG" 2>/dev/null | grep "accepted" | tail -n 100 \
           | awk '{print $4}' | cut -d':' -f1 | awk -F'.' 'NF>=3{print $1"."$2"."$3}' | sort -u | wc -l)

    if [[ "$nets" -gt "$limit" ]]; then
      strikes[$user]=$(( ${strikes[$user]:-0} + 1 ))
      if [[ "${strikes[$user]}" -ge "$VIOLATION_THRESHOLD" ]]; then
        acc_xray_suspend "vmess" "$user" "iplimit"
        tg_send "<b>[ VMESS IP LIMIT ]</b>%0AUsername: <code>${user}</code>%0AIPs: ${nets}/${limit}%0AStatus: suspended"
        unset 'strikes[$user]'
      fi
    else
      unset 'strikes[$user]'
    fi
  done < <(db_query "SELECT username, limit_ip FROM accounts WHERE protocol='vmess' AND status='active';")
  sleep 30
done
