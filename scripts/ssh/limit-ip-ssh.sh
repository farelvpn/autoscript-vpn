#!/usr/bin/env bash
# ========================================================
# Project: Autoscript VPN by risqinf
# Description: SSH IP-limit enforcement (DB-driven, single pass; run by cron)
# License: Apache License 2.0 (see LICENSE file)
# Repository: https://github.com/risqinf/autoscript
# ========================================================
. /usr/local/sbin/lib/account.sh

db_init

if   [ -e /var/log/secure ];   then LOG=/var/log/secure
elif [ -e /var/log/auth.log ]; then LOG=/var/log/auth.log
else exit 0
fi

while IFS='|' read -r user limit; do
  [[ -z "$user" ]] && continue
  [[ "$limit" -le 0 ]] && continue

  db_ips=$(grep -i "dropbear" "$LOG" 2>/dev/null | grep -i "Password auth succeeded" | grep -w "'$user'" | awk '{print $(NF)}')
  ssh_ips=$(grep -i "sshd" "$LOG" 2>/dev/null | grep "Accepted" | grep -w "$user" | awk '{for(i=1;i<=NF;i++) if($i=="from") print $(i+1)}')
  cnt=$(printf "%s\n%s\n" "$db_ips" "$ssh_ips" | grep '[0-9]' | sort -u | wc -l)

  if [[ "$cnt" -gt "$limit" ]]; then
    pkill -KILL -u "$user" 2>/dev/null
    db_audit "ip_limit_kick" "ssh" "$user" "ips=${cnt}/${limit}"
    tg_send "<b>[ SSH IP LIMIT ]</b>%0AUsername: <code>${user}</code>%0AIPs: ${cnt}/${limit}%0AAction: sessions terminated"
  fi
done < <(db_query "SELECT username, limit_ip FROM accounts WHERE protocol='ssh' AND status='active';")
exit 0
