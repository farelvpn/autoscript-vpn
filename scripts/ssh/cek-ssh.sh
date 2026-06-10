#!/usr/bin/env bash
# ========================================================
# Project: Autoscript VPN by risqinf
# Description: SSH live session monitor (WS bandwidth correlation)
# License: Apache License 2.0 (see LICENSE file)
# Repository: https://github.com/risqinf/autoscript
# ========================================================
# Correlation:
#   ssh-ws.log [CONNECT]  -> sessionID, real client IP, proxy-port
#   ssh-ws.log [MONITOR]  -> live TX / RX / Total / uptime per session
#   /var/log/secure       -> proxy-port -> SSH username (dropbear/sshd auth)
#   ss (live sockets)     -> proxy-port still connected to dropbear:109
# ========================================================
. /usr/local/sbin/lib/account.sh

db_init

WSLOG="/var/log/ssh-ws.log"
if   [ -e /var/log/secure ];   then SECLOG=/var/log/secure
elif [ -e /var/log/auth.log ]; then SECLOG=/var/log/auth.log
else SECLOG=""
fi

# --- 1) proxy-port -> username map (last auth per port wins) ---
declare -A PORT2USER
if [[ -n "$SECLOG" ]]; then
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
fi

# --- 2) live proxy-ports (sockets to dropbear:109) ---
declare -A LIVEPORT
while read -r p; do
  [[ -n "$p" ]] && LIVEPORT[$p]=1
done < <(ss -tnH 2>/dev/null | grep '127.0.0.1:109' \
          | grep -oE '127\.0\.0\.1:[0-9]+' | grep -v ':109$' | cut -d: -f2 | sort -u)

# --- 3) ssh-ws.log -> per active session: proxyport|clientip|tx|rx|total|up ---
declare -A S_PORT S_CIP S_TX S_RX S_TOT S_UP
if [[ -f "$WSLOG" ]]; then
  while IFS='|' read -r pport cip tx rx tot up; do
    [[ -z "$pport" ]] && continue
    S_PORT[$pport]=1
    S_CIP[$pport]="$cip"; S_TX[$pport]="$tx"; S_RX[$pport]="$rx"
    S_TOT[$pport]="$tot"; S_UP[$pport]="$up"
  done < <(
    awk '
      function sid(x){ gsub(/[\[\]]/,"",x); return x }
      $3=="[CONNECT]" {
        s=sid($4); pp=$0; sub(/.*proxy-port:/,"",pp); gsub(/[^0-9]/,"",pp);
        SIDPP[s]=pp; SIDCIP[s]=$5;
      }
      $3=="[MONITOR]" {
        s=sid($4); tx=""; rx=""; tot=""; upv="";
        for(i=1;i<=NF;i++){
          if($i ~ /^up:/)    upv=substr($i,4);
          if($i ~ /^TX:/)    tx=substr($i,4)" "$(i+1);
          if($i ~ /^RX:/)    rx=substr($i,4)" "$(i+1);
          if($i ~ /^Total:/) tot=substr($i,7)" "$(i+1);
        }
        SIDTX[s]=tx; SIDRX[s]=rx; SIDTOT[s]=tot; SIDUP[s]=upv;
        if($5 ~ /:/) SIDCIP[s]=$5;
      }
      END {
        for(s in SIDPP){
          pp=SIDPP[s];
          print pp"|"SIDCIP[s]"|"SIDTX[s]"|"SIDRX[s]"|"SIDTOT[s]"|"SIDUP[s]
        }
      }
    ' "$WSLOG" 2>/dev/null
  )
fi

clear
ui_header "SSH LIVE SESSION MONITOR"
echo ""

declare -A USER_SESS
total_live=0

# Iterate live proxy-ports (authoritative liveness), correlate to user + bandwidth.
for pport in "${!LIVEPORT[@]}"; do
  user="${PORT2USER[$pport]}"
  [[ -z "$user" ]] && user="detecting..."
  cip="${S_CIP[$pport]:-?}"; cip="${cip%%:*}"
  up="${S_UP[$pport]:-?}"
  tx="${S_TX[$pport]:--}"; rx="${S_RX[$pport]:--}"; tot="${S_TOT[$pport]:--}"
  USER_SESS[$user]=$(( ${USER_SESS[$user]:-0} + 1 ))
  total_live=$((total_live+1))
  ui_sep
  printf " ${WHITE}%-12s${NC} : %s\n" "Username" "$user"
  printf " ${WHITE}%-12s${NC} : %s\n" "Client IP" "$cip"
  printf " ${WHITE}%-12s${NC} : %s\n" "Uptime" "$up"
  printf " ${WHITE}%-12s${NC} : TX %s | RX %s | Total %s\n" "Bandwidth" "$tx" "$rx" "$tot"
done

if [[ $total_live -eq 0 ]]; then
  ui_sep
  echo -e " ${YELLOW}No active SSH sessions.${NC}"
fi

ui_sep
echo -e " ${WHITE}PER-USER SESSIONS (vs IP limit)${NC}"
ui_sep
while IFS='|' read -r u limit; do
  [[ -z "$u" ]] && continue
  cnt=${USER_SESS[$u]:-0}
  [[ "$limit" == "0" ]] && limit="Unlimited"
  mark=""
  [[ "$limit" != "Unlimited" && "$cnt" -gt "$limit" ]] && mark="  ${RED}[OVER LIMIT]${NC}"
  printf " %-14s %s/%s%b\n" "$u" "$cnt" "$limit" "$mark"
done < <(db_query "SELECT username, limit_ip FROM accounts WHERE protocol='ssh' AND status='active' ORDER BY username;")
ui_sep
echo -e " Total live sessions : ${GREEN}${total_live}${NC}"
ui_foot
ui_back
menu
