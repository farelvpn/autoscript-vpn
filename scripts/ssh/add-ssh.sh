#!/usr/bin/env bash
# ========================================================
# Project: Autoscript VPN by risqinf
# Description: Create SSH account (SQLite-backed)
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
echo -e "${WHITE}  CREATE SSH ACCOUNT${NC}"
line

while true; do
  read -rp "Username: " user
  if ! valid_username "$user"; then err "Username 3-32 chars: letters, numbers, underscore."; continue; fi
  if db_account_exists "ssh" "$user" || id "$user" &>/dev/null; then err "Username '$user' already exists."; continue; fi
  break
done

while true; do
  read -rp "Password: " pass
  valid_password "$pass" && break
  err "Password must be non-empty, no spaces/tabs/newlines/colons."
done

while true; do read -rp "Limit IP (number): " limit_ip; valid_number "$limit_ip" && break; err "Number only."; done
while true; do read -rp "Expired (days): " days; valid_days "$days" && break; err "Days must be 1-3650."; done

if ! acc_ssh_create "$user" "$pass" "$limit_ip" "$days"; then
  err "Failed to create SSH account."; exit 1
fi

exp_epoch=$(db_get_field "ssh" "$user" "expired_at")
exp_disp=$(date -d "@${exp_epoch}" +"%d-%m-%Y %H:%M:%S")

tg_send "<b>[ SSH ACCOUNT ]</b>
Domain   : <code>${domain}</code> / <code>${ip}</code>
Username : <code>${user}</code>
Password : <code>${pass}</code>
Limit IP : <code>${limit_ip}</code>
Expired  : <code>${exp_disp}</code>"

clear
line
echo -e "${WHITE}  SSH ACCOUNT CREATED${NC}"
line
echo -e "Domain   : ${domain} / ${ip}"
echo -e "Username : ${user}"
echo -e "Password : ${pass}"
echo -e "Limit IP : ${limit_ip}"
echo -e "Expired  : ${exp_disp}"
line
echo -e "Port OpenSSH : 109     Port WS HTTP : 80, 8888"
echo -e "Port WS TLS  : 443     Port BadVPN  : 7300"
echo -e "Port OpenVPN : 1194 (TCP) / 2200 (UDP)"
line
echo -e "Config HTTP Custom: ${domain}:1-65535@${user}:${pass}"
line
read -n 1 -s -r -p "Press any key to menu..."
menu
