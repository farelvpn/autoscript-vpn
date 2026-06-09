#!/usr/bin/env bash
# ========================================================
# Project: Autoscript VPN by risqinf
# Description: Bulk account generator (DB-driven, all protocols)
# License: Apache License 2.0 (see LICENSE file)
# Repository: https://github.com/risqinf/autoscript
# ========================================================
. /usr/local/sbin/lib/account.sh

require_root
db_init
domain=$(get_domain)
ip=$(get_ip)

clear
line
echo -e "${WHITE}  AUTO BULK ACCOUNT GENERATOR${NC}"
line
echo "1. SSH    2. VLESS    3. VMESS    4. TROJAN"
line
read -rp "Select Protocol (1-4): " sel
case "$sel" in
  1) proto="ssh" ;;
  2) proto="vless" ;;
  3) proto="vmess" ;;
  4) proto="trojan" ;;
  *) err "Invalid selection."; exit 1 ;;
esac

read -rp "Account Prefix (e.g. user): " prefix
valid_prefix "$prefix" || { err "Prefix 1-16 chars: letters, numbers, underscore."; exit 1; }
read -rp "Number of Accounts: " count
valid_number "$count" || { err "Count must be a number."; exit 1; }
(( count >= 1 )) || { err "Count must be >= 1."; exit 1; }
read -rp "Expired (days): " days
valid_days "$days" || { err "Days must be 1-3650."; exit 1; }
read -rp "Limit IP: " limit_ip
valid_number "$limit_ip" || { err "Limit IP must be a number."; exit 1; }

quota=0
if [[ "$proto" != "ssh" ]]; then
  read -rp "Quota (GB, 0=unlimited): " quota
  valid_number "$quota" || { err "Quota must be a number."; exit 1; }
fi

exp_epoch=$(( $(date +%s) + days * 86400 ))
success=0

for (( i=1; i<=count; i++ )); do
  user="${prefix}$(gen_pass 4 | tr 'A-Z' 'a-z')"
  if [[ "$proto" == "ssh" ]]; then
    pass=$(gen_pass 10)
    acc_ssh_create "$user" "$pass" "$limit_ip" "$days" >/dev/null 2>&1 && {
      success=$((success+1)); echo "SSH  $user / $pass"; }
  else
    secret=$(gen_uuid)
    acc_xray_create "$proto" "$user" "$secret" "$quota" "$limit_ip" "$exp_epoch" >/dev/null 2>&1 && {
      success=$((success+1)); echo "${proto^^}  $user / $secret"; }
  fi
done

line
ok "Created ${success}/${count} ${proto} accounts."
line
read -n 1 -s -r -p "Press any key to menu..."
menu
