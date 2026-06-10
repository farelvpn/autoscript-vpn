#!/usr/bin/env bash
# ========================================================
# Project: Autoscript VPN by risqinf
# Description: High-level account service (DB + Xray config + system user)
# License: Apache License 2.0 (see LICENSE file)
# Repository: https://github.com/risqinf/autoscript
# ========================================================
[[ -n "${__AS_ACCOUNT_LOADED:-}" ]] && return 0
__AS_ACCOUNT_LOADED=1

LIBD="$(dirname "${BASH_SOURCE[0]}")"
. "$LIBD/common.sh"
. "$LIBD/db.sh"
. "$LIBD/xraycfg.sh"

# ---- XRAY ACCOUNTS (vless/vmess/trojan) ----
# Create. Args: proto user secret quota_gb limit_ip expired_epoch
# Echoes nothing; returns 0/!=0. On success the account is in DB + config.
acc_xray_create() {
  local proto="$1" user="$2" secret="$3" quota_gb="$4" limit_ip="$5" exp_epoch="$6"
  local quota_bytes=0
  (( quota_gb > 0 )) && quota_bytes=$(( quota_gb * 1073741824 ))

  if db_account_exists "$proto" "$user" || cfg_client_exists "$user"; then
    err "username '$user' already exists"; return 9
  fi
  if db_secret_in_use "$secret" || cfg_secret_exists "$secret"; then
    err "secret/uuid already in use"; return 9
  fi

  # Config first (validated + rollback); then DB.
  if ! cfg_add_client "$proto" "$user" "$secret"; then
    err "failed to update xray config"; return 1
  fi
  if ! db_insert_account "$proto" "$user" "$secret" "$quota_bytes" "$limit_ip" "$exp_epoch"; then
    # rollback config
    cfg_del_client "$proto" "$user"
    err "failed to write database"; return 1
  fi
  db_audit "create" "$proto" "$user" "quota=${quota_gb}GB ip=${limit_ip}"
  systemctl restart xray.service >/dev/null 2>&1
  return 0
}

# Soft-delete (status=deleted) + remove from config. Recoverable from DB.
acc_xray_delete() {
  local proto="$1" user="$2"
  db_account_exists "$proto" "$user" || { err "account not found"; return 4; }
  cfg_del_client "$proto" "$user" || { err "failed to update config"; return 1; }
  db_set_status "$proto" "$user" "deleted"
  db_audit "delete" "$proto" "$user" ""
  systemctl restart xray.service >/dev/null 2>&1
  return 0
}

# Suspend (status=suspended) + remove from config but keep DB row active-data.
acc_xray_suspend() {
  local proto="$1" user="$2" reason="${3:-limit}"
  db_account_exists "$proto" "$user" || return 4
  cfg_del_client "$proto" "$user"
  db_set_status "$proto" "$user" "suspended"
  db_audit "suspend" "$proto" "$user" "$reason"
  systemctl restart xray.service >/dev/null 2>&1
  return 0
}

# Renew. Args: proto user add_days  -> extends from max(now, current expiry)
acc_xray_renew() {
  local proto="$1" user="$2" days="$3"
  local cur now base new
  cur=$(db_get_field "$proto" "$user" "expired_at")
  [[ -z "$cur" ]] && { err "account not found"; return 4; }
  now=$(date +%s)
  base=$cur; (( cur < now )) && base=$now
  new=$(( base + days * 86400 ))
  db_set_expired "$proto" "$user" "$new"
  db_audit "renew" "$proto" "$user" "+${days}d"
  echo "$new"
  return 0
}

# ---- SSH ACCOUNTS ----
acc_ssh_create() {
  local user="$1" pass="$2" limit_ip="$3" days="$4"
  local exp_epoch exp_system
  exp_epoch=$(( $(date +%s) + days * 86400 ))
  exp_system=$(date -d "@${exp_epoch}" +%Y-%m-%d)

  if db_account_exists "ssh" "$user" || id "$user" &>/dev/null; then
    err "username '$user' already exists"; return 9
  fi
  local nologin
  nologin=$(ensure_nologin_shell); [[ -z "$nologin" ]] && nologin=/usr/sbin/nologin
  useradd -e "$exp_system" -M -N -s "$nologin" "$user" || { err "useradd failed"; return 1; }
  echo "${user}:${pass}" | chpasswd || { userdel --force "$user" >/dev/null 2>&1; err "chpasswd failed"; return 1; }
  db_insert_account "ssh" "$user" "$pass" 0 "$limit_ip" "$exp_epoch"
  db_audit "create" "ssh" "$user" "ip=${limit_ip} days=${days}"
  return 0
}

acc_ssh_delete() {
  local user="$1"
  db_account_exists "ssh" "$user" || { err "account not found"; return 4; }
  id "$user" &>/dev/null && userdel --force "$user" >/dev/null 2>&1
  db_set_status "ssh" "$user" "deleted"
  db_audit "delete" "ssh" "$user" ""
  systemctl restart dropbear >/dev/null 2>&1
  return 0
}

acc_ssh_renew() {
  local user="$1" days="$2"
  local cur now base new
  cur=$(db_get_field "ssh" "$user" "expired_at")
  [[ -z "$cur" ]] && { err "account not found"; return 4; }
  now=$(date +%s)
  base=$cur; (( cur < now )) && base=$now
  new=$(( base + days * 86400 ))
  db_set_expired "ssh" "$user" "$new"
  id "$user" &>/dev/null && chage -E "$(date -d "@${new}" +%Y-%m-%d)" "$user" 2>/dev/null
  db_audit "renew" "ssh" "$user" "+${days}d"
  echo "$new"
  return 0
}

# ---- SHARED DISPLAY HELPERS ----
# Full SSH account detail to the terminal. Args: user pass ip_disp exp_disp [title]
ssh_print_cli() {
  local user="$1" pass="$2" ip_disp="$3" exp_disp="$4" title="${5:-SSH ACCOUNT}"
  local d; d=$(get_domain); local sip; sip=$(get_ip)
  echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\e[0m"
  printf "\e[0;42;30m %-56s \e[0m\n" "$title"
  echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\e[0m"
  echo -e " Username     : ${user}"
  echo -e " Password     : ${pass}"
  echo -e " Host / IP    : ${d} / ${sip}"
  echo -e " Limit IP     : ${ip_disp}"
  echo -e " Expired      : ${exp_disp}"
  echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\e[0m"
  echo -e " Port OpenSSH : 22, 109"
  echo -e " Port WS HTTP : 80, 8888"
  echo -e " Port WS TLS  : 443"
  echo -e " Port BadVPN  : 7300 (UDPGW)"
  echo -e " Port OpenVPN : 1194 (TCP) / 2200 (UDP)"
  echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\e[0m"
  echo -e " Config HTTP Custom :"
  echo -e " ${d}:1-65535@${user}:${pass}"
  echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\e[0m"
  echo -e " Payload (WS) :"
  echo -e " GET /ssh HTTP/1.1[crlf]Host: ${d}[crlf]Upgrade: websocket[crlf][crlf]"
  echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\e[0m"
  echo -e " OVPN TCP     : https://${d}/risqinf/openvpn/tcp.ovpn"
  echo -e " OVPN UDP     : https://${d}/risqinf/openvpn/udp.ovpn"
  echo -e " OVPN Bundle  : https://${d}/risqinf/openvpn/"
  echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\e[0m"
}

# Full SSH account detail as Telegram HTML. Args: user pass ip_disp exp_disp [title]
ssh_tg_text() {
  local user="$1" pass="$2" ip_disp="$3" exp_disp="$4" title="${5:-SSH ACCOUNT}"
  local d; d=$(get_domain); local sip; sip=$(get_ip)
  cat <<EOF
<b>━━━━━━━━━━━━━━━━━━━━━━━━━━━</b>
<b>      ⊹ ${title} ⊹</b>
<b>━━━━━━━━━━━━━━━━━━━━━━━━━━━</b>
<b>Username  :</b> <code>${user}</code>
<b>Password  :</b> <code>${pass}</code>
<b>Host/IP   :</b> <code>${d}</code> / <code>${sip}</code>
<b>Limit IP  :</b> <code>${ip_disp}</code>
<b>Expired   :</b> <code>${exp_disp}</code>
<b>━━━━━━━━━━━━━━━━━━━━━━━━━━━</b>
<b>Port OpenSSH :</b> <code>22, 109</code>
<b>Port WS HTTP :</b> <code>80, 8888</code>
<b>Port WS TLS  :</b> <code>443</code>
<b>Port BadVPN  :</b> <code>7300</code>
<b>Port OpenVPN :</b> <code>1194 (TCP), 2200 (UDP)</code>
<b>━━━━━━━━━━━━━━━━━━━━━━━━━━━</b>
<b>Config HTTP Custom :</b>
<code>${d}:1-65535@${user}:${pass}</code>
<b>━━━━━━━━━━━━━━━━━━━━━━━━━━━</b>
<b>Payload :</b>
<code>GET /ssh HTTP/1.1[crlf]Host: ${d}[crlf]Upgrade: websocket[crlf][crlf]</code>
<b>━━━━━━━━━━━━━━━━━━━━━━━━━━━</b>
<b>OVPN TCP :</b> <code>https://${d}/risqinf/openvpn/tcp.ovpn</code>
<b>OVPN UDP :</b> <code>https://${d}/risqinf/openvpn/udp.ovpn</code>
<b>OVPN Dir :</b> <code>https://${d}/risqinf/openvpn/</code>
<b>━━━━━━━━━━━━━━━━━━━━━━━━━━━</b>
EOF
}

# ---- XRAY LOGIN MONITOR (shared by cek-vless/vmess/trojan) ----
# Human-readable bytes.
human_bytes() {
  local b="${1:-0}" u=(B KB MB GB TB) i=0
  while (( b >= 1024 && i < 4 )); do b=$(( b / 1024 )); ((i++)); done
  echo "${b} ${u[$i]}"
}

# Boxed per-account login monitor for an xray protocol.
# Counts only IPs seen in the most recent login window (last RECENT_SECS) so a
# single client that reconnected several times is not counted multiple times.
# Arg: protocol (vless|vmess|trojan)
xray_cek_monitor() {
  local proto="$1"
  local LOG="/var/log/xray/access.log"
  local RECENT_SECS=120          # only connections within the last 2 minutes
  local now_epoch; now_epoch=$(date +%s)

  clear
  ui_header "${proto^^} LOGIN MONITOR"
  echo ""

  local any=0
  while IFS='|' read -r user limit qb used exp; do
    [[ -z "$user" ]] && continue

    # Distinct client IPs from RECENT accepted log lines for this user.
    # Xray access log line: "2026/06/10 07:45:59 1.2.3.4:1234 accepted ... email: user"
    local ips
    ips=$(awk -v u="email: ${user}" -v now="$now_epoch" -v win="$RECENT_SECS" '
      index($0, u) && /accepted/ {
        # $1=date(YYYY/MM/DD) $2=time(HH:MM:SS) $3=src(ip:port)
        ts=$1" "$2; gsub("/","-",ts);
        cmd="date -d \""ts"\" +%s 2>/dev/null"; cmd | getline e; close(cmd);
        if (e == "" ) next;
        if (now - e <= win) {
          ip=$3; sub(/:[0-9]+$/,"",ip);
          if (ip != "") seen[ip]=1
        }
      }
      END { for (k in seen) print k }
    ' "$LOG" 2>/dev/null | sort -u)

    local cnt=0
    [[ -n "$ips" ]] && cnt=$(echo "$ips" | grep -c .)

    # Display values.
    local limd usedd quotad
    [[ "$limit" == "0" ]] && limd="Unlimited" || limd="$limit"
    usedd=$(human_bytes "${used:-0}")
    if [[ "$qb" == "0" ]]; then quotad="Unlimited"; else quotad=$(human_bytes "$qb"); fi

    any=1
    ui_sep
    printf " ${WHITE}%-12s${NC} : %s\n" "Username" "$user"
    printf " ${WHITE}%-12s${NC} : %s / %s IP\n" "Login IP" "$cnt" "$limd"
    printf " ${WHITE}%-12s${NC} : %s / %s\n" "Quota" "$usedd" "$quotad"
    printf " ${WHITE}%-12s${NC} : %s\n" "Expired" "$exp"
    if [[ -n "$ips" ]]; then
      printf " ${WHITE}%-12s${NC} :\n" "Active IPs"
      while read -r one; do [[ -n "$one" ]] && echo "                  - $one"; done <<< "$ips"
    else
      printf " ${WHITE}%-12s${NC} : %s\n" "Active IPs" "(none recently)"
    fi
    if [[ "$limd" != "Unlimited" && "$cnt" -gt "$limit" ]]; then
      echo -e "                  ${RED}[!] EXCEEDS IP LIMIT${NC}"
    fi
  done < <(db_query "SELECT username, limit_ip, quota_bytes, used_bytes,
                            datetime(expired_at,'unixepoch','localtime')
                     FROM accounts WHERE protocol='${proto}' AND status='active'
                     ORDER BY username;")

  ui_sep
  [[ $any -eq 0 ]] && echo -e " ${YELLOW}No active ${proto^^} accounts.${NC}"
  ui_foot
}
