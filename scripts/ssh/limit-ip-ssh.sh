#!/usr/bin/env bash
# ========================================================
# Project: Autoscript VPN by risqinf
# Description: SSH IP-limit enforcement (live-session correlated; run by timer)
# License: Apache License 2.0 (see LICENSE file)
# Repository: https://github.com/risqinf/autoscript
# ========================================================
# Counts only CURRENTLY-LIVE sessions (not historical log lines):
#   ss            -> live proxy-ports connected to dropbear:109
#   /var/log/secure -> proxy-port -> username
#   ssh-ws.log    -> proxy-port -> real client IP
# A user exceeding their limit on distinct live client IPs is disconnected.
# ========================================================
. /usr/local/sbin/lib/account.sh

db_init

WSLOG="/var/log/ssh-ws.log"
if   [ -e /var/log/secure ];   then SECLOG=/var/log/secure
elif [ -e /var/log/auth.log ]; then SECLOG=/var/log/auth.log
else exit 0
fi

# proxy-port -> username
declare -A PORT2USER
while read -r port user; do
  [[ -n "$port" && -n "$user" ]] && PORT2USER[$port]="$user"
done < <(
  awk '
    /dropbear\[/ && /Password auth succeeded/ {
      f=$NF; n=split(f,a,":"); port=a[n]; u="";
      for(i=1;i<=NF;i++){ if($i ~ /^\047.*\047$/){ u=$i; gsub(/\047/,"",u) } }
      if(port ~ /^[0-9]+$/ && u!="") print port, u
    }
    /sshd\[/ && /Accepted / {
      u=""; port="";
      for(i=1;i<=NF;i++){ if($i=="for") u=$(i+1); if($i=="port") port=$(i+1) }
      if(port ~ /^[0-9]+$/ && u!="") print port, u
    }
  ' "$SECLOG" 2>/dev/null
)

# proxy-port -> real client IP (from ssh-ws CONNECT lines)
declare -A PORT2CIP
if [[ -f "$WSLOG" ]]; then
  while IFS='|' read -r pport cip; do
    [[ -n "$pport" ]] && PORT2CIP[$pport]="${cip%%:*}"
  done < <(
    awk '$3=="[CONNECT]"{ pp=$0; sub(/.*proxy-port:/,"",pp); gsub(/[^0-9]/,"",pp); print pp"|"$5 }' "$WSLOG" 2>/dev/null
  )
fi

# Build per-user set of distinct live client IPs.
declare -A USER_IPS
while read -r pport; do
  [[ -z "$pport" ]] && continue
  u="${PORT2USER[$pport]}"; [[ -z "$u" ]] && continue
  cip="${PORT2CIP[$pport]}"; [[ -z "$cip" ]] && cip="port:$pport"
  case " ${USER_IPS[$u]} " in
    *" $cip "*) ;;
    *) USER_IPS[$u]="${USER_IPS[$u]} $cip" ;;
  esac
done < <(ss -tnH 2>/dev/null | grep '127.0.0.1:109' \
          | grep -oE '127\.0\.0\.1:[0-9]+' | grep -v ':109$' | cut -d: -f2 | sort -u)

# Enforce per active SSH account.
while IFS='|' read -r user limit; do
  [[ -z "$user" ]] && continue
  [[ "$limit" -le 0 ]] && continue
  ips="${USER_IPS[$user]}"
  cnt=$(echo "$ips" | tr ' ' '\n' | grep -c '[^[:space:]]')
  if [[ "$cnt" -gt "$limit" ]]; then
    pkill -KILL -u "$user" 2>/dev/null
    db_audit "ip_limit_kick" "ssh" "$user" "ips=${cnt}/${limit}"
    tg_send "<b>[ SSH IP LIMIT ]</b>%0AUsername: <code>${user}</code>%0AIPs: ${cnt}/${limit}%0AAction: sessions terminated"
  fi
done < <(db_query "SELECT username, limit_ip FROM accounts WHERE protocol='ssh' AND status='active';")
exit 0
